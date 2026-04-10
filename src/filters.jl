function gaussian_filter(data::Vector, k::Real)::Vector{Float32}
    k = Int(round(k))
    if length(data) < k
        @warn "window larger than dataset"
        return 0
    end
    sig = k/(3*2) #3 standard deviations from center value to edge
    k2::Int = ceil(k/2)
    x = LinRange(-k2,k2,2*k2)
    gx::Vector{Float32} = (1/sqrt(2*pi*sig)).*ℯ.^((-x.^2)./(2*sig^2))
    gx = gx .* 1/sum(gx) #normalize

    steprange = (k2):round(k/10):(length(data)-k2)
    outdata::Vector{Float32} = fill(Float32(0),length(steprange))

    for i = 1:length(steprange)
        j = steprange[i]
        datak = @view data[Int(j-k2+1):Int(j+k2)]
        outdata[i] = sum(datak.*gx)
    end
    
    return outdata
end

function modZ_filter(data::Vector,window::Real)
    window = round(window)
    m::Float64 = typemin(Float64)
    currSum::Float64 = 0
    currDiv::Float64 = 0
    outdata::Vector{Float32} = []
    for i = 1:Int(round(window/10)):(length(data)-window)
        datawindow = @view data[i:i+window]

        currSum = 0
        currDiv = 0

        #Modzoutlier causes issues with pulsing signals i.e. beacon light measurement (finds zero if window too big, could be desired behavior in some situations)
        
        xm = median(datawindow)
        MAD = median(abs.(datawindow .- xm))

        for e in datawindow
            if (0.6745*(e-xm))/MAD <= 3.5
                currSum += e
                currDiv += 1
            else
                continue
            end
        end
        

        #regular Z outlier (this outlier detection can be prone to being affected by large spikes and non normal distributed data, seems reliable for this use case)
        #=
        xm = mean(datawindow)
        xstd = std(datawindow)

        for e in datawindow
            if -3 <= ((e-xm)/xstd) <= 3
                currSum += e
                currDiv += 1
            else
                continue
            end
        end
        =#


        if currDiv == 0
            currMean = NaN
        else
            currMean = currSum/currDiv
        end
        if currMean >= m
            m = currMean
        end
        push!(outdata,currMean)
    end

    return outdata
end

function median_filter(data::Vector, k::Real)
    k = Int(round(k))
    if length(data) < k
        @warn "window larger than dataset"
        return 0
    end
    k2::Int = ceil(k/2)
    outdata::Vector{Float32} = []

    for i = (k2):(length(data)-k2)
        push!(outdata,median(data[Int(i-k2+1):Int(i+k2)]))
    end
    outdata = [fill(outdata[1],k2);outdata;fill(outdata[1],k2-1)]
    return outdata
end

function savitzkyGolay() #smoothing algorithm unimplemented
end