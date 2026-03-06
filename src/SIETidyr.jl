function tidySIE(sieData::Dict)
    sieFrame = DataFrame("Channel" => [], "Data" => [], "Time" => [], "Units" => [], "SR" => [])
    for key in keys(sieData)
        Data = Vector{Float64}(sieData[key]["data"])
        Time = Vector{Float64}(collect(sieData[key]["time"]))
        dataL = length(Data)

        Channel = fill(string(sieData[key]["id"]) *". "* string(key),dataL)
        SR = fill(sieData[key]["sr"],dataL)
        Units = fill(sieData[key]["units"],dataL)

        frameAppend = DataFrame("Channel" => Channel, "Data" => Data, "Time" => Time, "Units" => Units, "SR" => SR)

        append!(sieFrame,frameAppend)
    end


    return sieFrame
end