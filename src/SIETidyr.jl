#may need more fixes with decoder change

function tidySIE(sieData::Dict)
    sieFrame = DataFrame("Channel" => [], "Data" => [], "Time" => [], "Units" => [], "SR" => [])
    for key in keys(sieData)
        Data = Vector{Float64}(sieData[key]["v1"])
        Time = Vector{Float64}(collect(sieData[key]["v0"]))
        dataL = length(Data)

        Channel = fill(string(sieData[key]["id"]) *". "* string(key),dataL)
        SR = fill(sieData[key]["tags"]["core:sample_rate"],dataL)
        Units = fill(sieData[key]["tags"]["dim1"]["units"],dataL)

        frameAppend = DataFrame("Channel" => Channel, "Data" => Data, "Time" => Time, "Units" => Units, "SR" => SR)

        append!(sieFrame,frameAppend)
    end


    return sieFrame
end