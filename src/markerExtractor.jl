#=
markExtract: split every channel of a SIE file into segments delimited
by the longest run of each unique level on a digital marker channel.
Built directly on the SomatSIE 0.3 API.
=#

"""
    markExtract(file::SomatSIE.SieFile, markKey::AbstractString;
                onlyLargest::Bool = true)
    markExtract(path::AbstractString, markKey::AbstractString;
                onlyLargest::Bool = true)

For every distinct integer level on the marker channel `markKey`,
return slices of every other numeric channel covering the marker's
largest contiguous run at that level.

Returns:

    Dict{String, Dict{Int, Vector}}  # channel name -> marker level -> slice
"""
function markExtract(file::SomatSIE.SieFile, markKey::AbstractString;
                     onlyLargest::Bool = true)
    onlyLargest || @error "onlyLargest = false is not yet supported"

    markCh = findchannelbyname(file, String(markKey))
    markCh === nothing && error("marker channel not found: ", markKey)

    mData = valuevec(file, markCh)
    mData isa AbstractVector{<:Real} ||
        error("marker channel '", markKey, "' is not a numeric series")

    mSR = Float64(tagget(SomatSIE.tags(markCh), "core:sample_rate", NaN))
    isnan(mSR) && error("marker channel '", markKey,
                        "' has no core:sample_rate tag")

    mInd = markerIndex(mData, mSR)

    extracted = Dict{String, Dict{Int, Vector}}()
    for ch in SomatSIE.channels(file)
        chName = SomatSIE.name(ch)
        dims   = SomatSIE.dimensions(ch)
        length(dims) >= 2 || continue

        chData = valuevec(file, ch)
        chData isa AbstractVector{<:Real} || continue

        chSR = Float64(tagget(SomatSIE.tags(ch), "core:sample_rate", NaN))
        isnan(chSR) && continue

        slices = Dict{Int, Vector}()
        for (level, (tStart, tEnd)) in mInd
            i0 = Int(floor(tStart * chSR) + 1)
            i1 = Int(floor(tEnd   * chSR) + 1)
            i0 = max(i0, 1); i1 = min(i1, length(chData))
            i0 <= i1 && (slices[level] = chData[i0:i1])
        end
        extracted[chName] = slices
    end
    return extracted
end

markExtract(path::AbstractString, markKey::AbstractString; kwargs...) =
    withfile(f -> markExtract(f, markKey; kwargs...), path)

"""
    markerIndex(mData, mSR) -> Dict{Int, Tuple{Float64,Float64}}

Internal: scan `mData` for runs of equal integer level and return,
for each level, the (start, end) time of its longest run in seconds.
"""
function markerIndex(mData::AbstractVector{<:Real}, mSR::Real)
    indexDict = Dict{Int, Vector{Tuple{Int,Int}}}()
    N = length(mData)
    let
        prevValue::Int = 0
        indexStart::Int = 1
        indexEnd::Int   = 0
        for i = 1:N
            currValue = Int(mData[i])
            if ((currValue != prevValue) || (i == N)) && i != 1
                indexEnd = i - 1
                if !haskey(indexDict, prevValue)
                    indexDict[prevValue] = Tuple{Int,Int}[]
                end
                push!(indexDict[prevValue], (indexStart, indexEnd))
                indexStart = i
            end
            prevValue = currValue
        end
    end
    for j in keys(indexDict)
        let
            maxRange::Int = 0
            maxInd::Int   = 1
            for l in eachindex(indexDict[j])
                rng = indexDict[j][l][2] - indexDict[j][l][1]
                if rng > maxRange
                    maxRange = rng
                    maxInd   = l
                end
            end
            indexDict[j] = [indexDict[j][maxInd]]
        end
    end
    out = Dict{Int, Tuple{Float64,Float64}}()
    for k in keys(indexDict)
        out[k] = (Float64((indexDict[k][1][1] - 1) / mSR),
                  Float64((indexDict[k][1][2] - 1) / mSR))
    end
    return out
end
