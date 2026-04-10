function moving_mean(x::Vector, k::Int)
    n = length(x)
    if n < k
        return Float64[]
    end
    m = similar(x, n - k + 1)
    s = sum(@views x[1:k])
    m[1] = s / k
    for i in 2:(n - k + 1)
        s = s - x[i - 1] + x[i + k - 1]
        m[i] = s / k
    end
    return m
end

function sustained_max_old(data::Vector, percentile::Real , window::Int)
    percentileValue::Float64 = quantile(data, percentile)
    filtered_data::Vector{Real} = filter(x -> x <= percentileValue, data)
    susMax = maximum(moving_mean(filtered_data,window))
    return susMax
end

function sustained_max(data::Vector{<:Real}, window::Int)
    m::Float64 = typemin(Float64)
    currSum::Float64 = 0
    currDiv::Float64 = 0
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
            currMean = 0
        else
            currMean = currSum/currDiv
        end
        if currMean >= m
            m = currMean
        end
    end

    return m

end
