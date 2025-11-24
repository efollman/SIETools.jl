function CHInfo(sieData::Dict)
    keyList::Vector{String} = []
    idList::Vector{UInt} = []
    
    for key in keys(sieData)
        push!(keyList,key)
        push!(idList, sieData[key]["id"])
    end

    df = DataFrame(id = sort(idList), name = "", description = "", units = "", sr = NaN, datatype = "", sampleN = NaN, filtfreq = NaN, filttype = "", label = "", range = (NaN,NaN), timelabel = "", timeunits = "", eunits = "", erange = (NaN,NaN))

    permList::Vector{UInt} = sortperm(idList)

    for i in 1:nrow(df)
        df[i,"name"] = keyList[permList[i]]
        df[i,"description"] = sieData[keyList[permList[i]]]["description"]
        df[i,"units"] = sieData[keyList[permList[i]]]["units"]
        df[i,"sr"] = sieData[keyList[permList[i]]]["sr"]
        df[i,"datatype"] = string(sieData[keyList[permList[i]]]["datatype"])
        df[i,"sampleN"] = sieData[keyList[permList[i]]]["sampleN"]
        df[i,"filtfreq"] = sieData[keyList[permList[i]]]["filtfreq"]
        df[i,"filttype"] = sieData[keyList[permList[i]]]["filttype"]
        df[i,"label"] = sieData[keyList[permList[i]]]["label"]
        df[i,"range"] = sieData[keyList[permList[i]]]["range"]
        df[i,"timelabel"] = sieData[keyList[permList[i]]]["timelabel"]
        df[i,"timeunits"] = sieData[keyList[permList[i]]]["timeunits"]
        df[i,"eunits"] = sieData[keyList[permList[i]]]["eunits"]
        df[i,"erange"] = sieData[keyList[permList[i]]]["erange"]
    end

    return df
end