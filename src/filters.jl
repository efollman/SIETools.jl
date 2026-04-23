function gaussian_filter(data::AbstractVector, k::Real)::Vector{Float32}
    k = Int(round(k))
    if length(data) < k
        @warn "window larger than dataset"
        return 0
    end
    sig = k / (3 * 2) # 3 standard deviations from center value to edge
    k2::Int = ceil(k / 2)
    klen = 2 * k2
    x = LinRange(-k2, k2, klen)
    gx::Vector{Float32} = (1 / sqrt(2 * pi * sig)) .* ℯ .^ ((-x .^ 2) ./ (2 * sig^2))
    gx ./= sum(gx) # normalize

    step = max(1, Int(round(k / 10)))
    steprange = (k2):step:(length(data) - k2)
    outdata::Vector{Float32} = Vector{Float32}(undef, length(steprange))

    @inbounds for i in eachindex(steprange)
        j = steprange[i]
        base = j - k2  # window starts at base+1
        acc = zero(Float32)
        @simd for n in 1:klen
            acc += Float32(data[base + n]) * gx[n]
        end
        outdata[i] = acc
    end

    return outdata
end

function modZ_filter(data::AbstractVector, window::Real)
    window = Int(round(window))
    wlen = window + 1  # original code used data[i:i+window], inclusive
    n = length(data)
    if n < wlen
        @warn "window larger than dataset"
        return Float32[]
    end

    step = max(1, Int(round(window / 10)))
    starts = 1:step:(n - window)
    outdata = Vector{Float32}(undef, length(starts))

    buf  = Vector{Float64}(undef, wlen)  # window values (mutated by partialsort!)
    devs = Vector{Float64}(undef, wlen)  # |x - median| (mutated by partialsort!)

    # Helper: median via partialsort! on a buffer (mutates buf)
    @inline function _median!(b::Vector{Float64})
        L = length(b)
        if isodd(L)
            return partialsort!(b, (L + 1) >>> 1)
        else
            mid = L >>> 1
            hi  = partialsort!(b, mid + 1)        # places (mid+1)-th smallest at index mid+1
            lo  = maximum(@view b[1:mid])         # max of the lower half == mid-th order stat
            return 0.5 * (lo + hi)
        end
    end

    @inbounds for (oi, i) in enumerate(starts)
        # Copy window into buf
        @simd for j in 1:wlen
            buf[j] = Float64(data[i + j - 1])
        end

        xm = _median!(buf)

        # MAD: |x - xm| -> devs, then median of devs
        @simd for j in 1:wlen
            devs[j] = abs(Float64(data[i + j - 1]) - xm)
        end
        MAD = _median!(devs)

        # Modified Z-score filtered mean. Note: pulsing signals can collapse to ~0 if window is too large.
        currSum = 0.0
        currDiv = 0
        if MAD == 0.0
            # All deviations zero -> every point has score 0 (within threshold)
            @simd for j in 1:wlen
                currSum += Float64(data[i + j - 1])
            end
            currDiv = wlen
        else
            inv_mad = 0.6745 / MAD
            for j in 1:wlen
                e = Float64(data[i + j - 1])
                if (e - xm) * inv_mad <= 3.5
                    currSum += e
                    currDiv += 1
                end
            end
        end

        outdata[oi] = currDiv == 0 ? Float32(NaN) : Float32(currSum / currDiv)
    end

    return outdata
end

function median_filter(data::AbstractVector, k::Real)
    k = Int(round(k))
    n = length(data)
    if n < k
        @warn "window larger than dataset"
        return 0
    end
    k2::Int = ceil(k / 2)
    klen = 2 * k2  # actual sliding window length, matches the original [i-k2+1 : i+k2]
    nout = n - k2 - k2 + 1  # number of centers i = k2 .. n-k2

    core = Vector{Float32}(undef, nout)

    # Rolling-median over a sorted buffer.
    # Insert/delete via binary search: O(log klen) lookup + O(klen) shift.
    # Far cheaper than calling median() (full sort) on each overlapping window.
    sorted = Vector{Float64}(undef, klen)
    @inbounds begin
        # Initial fill from data[1:klen] (window centered at i = k2)
        for j in 1:klen
            sorted[j] = Float64(data[j])
        end
        sort!(sorted)

        # Median helper for already-sorted buffer
        @inline _med(s) = isodd(klen) ? s[(klen + 1) >>> 1] :
                          0.5 * (s[klen >>> 1] + s[(klen >>> 1) + 1])

        core[1] = Float32(_med(sorted))

        for c in 2:nout
            # Sliding from window starting at (c-1) to window starting at c:
            # remove data[c-1], insert data[c-1+klen]
            outv = Float64(data[c - 1])
            inv  = Float64(data[c - 1 + klen])

            # Remove outv: locate and shift left
            ridx = searchsortedfirst(sorted, outv)
            # ridx should be a valid index where sorted[ridx] == outv
            @simd for j in ridx:(klen - 1)
                sorted[j] = sorted[j + 1]
            end

            # Insert inv into the (now klen-1 valid entries) buffer
            iidx = searchsortedfirst(@view(sorted[1:klen - 1]), inv)
            for j in (klen):-1:(iidx + 1)
                sorted[j] = sorted[j - 1]
            end
            sorted[iidx] = inv

            core[c] = Float32(_med(sorted))
        end
    end

    # Pad to original length, matching the previous behavior:
    # [fill(first, k2); core; fill(first, k2-1)]
    outdata = Vector{Float32}(undef, k2 + nout + (k2 - 1))
    fill!(@view(outdata[1:k2]), core[1])
    copyto!(outdata, k2 + 1, core, 1, nout)
    fill!(@view(outdata[k2 + nout + 1:end]), core[1])
    return outdata
end

function savitzkyGolay() #smoothing algorithm unimplemented
end