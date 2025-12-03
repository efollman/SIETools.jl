#=
WIP Untested & Unused in this test.
Started this here as marker index was being used a lot.
This is probably a better way to handle the data in the future.
didnt implement here as it works differently and i didnt want to refactor scripts, so unfortunately absurd copy paste code it is
 
-Evan Follman
=#
function markExtract(sieData::Dict, markKey::String; onlyLargest::Bool = true)
    if onlyLargest == false
        @error "onlyLargest = false is not yet supported"
    end
    mData::Vector{<:Real} = sieData[markKey]["data"]
    mSR::Float64 = sieData[markKey]["sr"]
    mInd::Dict{UInt,Tuple{Float64,Float64}} = markerIndex(mData,mSR)

    extractedData::Dict{String,Dict{Int,Vector{<:Real}}} = Dict()
    chST::Float64 = 0
    
    for key in keys(sieData)
        extractedData[key] = Dict()
        for indKey in keys(mInd)
            chData = sieData[key]["data"]
            chSR = sieData[key]["sr"]
            extractedData[key][indKey] = chData[Int(floor(mInd[indKey][1]*chSR)+1):Int(floor(mInd[indKey][2]*chSR)+1)]

        end
    end

    return extractedData




end


function markerIndex(mData,mSR)
    indexDict::Dict{Int, Vector{Tuple{Int,Int}}} = Dict()
    N::UInt = length(mData)
    let
        prevValue::Int = 0
        indexStart::UInt = 1
        indexEnd::UInt = 0
        for i = 1:N
            currValue = Int(mData[i])
            if ((currValue != prevValue) || (i == N)) && i != 1
                indexEnd = i - 1
                if !haskey(indexDict,prevValue)
                    indexDict[prevValue] = []
                end
                indexDict[prevValue] = push!(indexDict[prevValue],(indexStart,indexEnd))
                indexStart = i
            end
            prevValue = currValue
        end
    end
    for j in keys(indexDict)
        let
            maxRange::Int = 0
            maxInd::Int = 1
            for l in eachindex(indexDict[j])
                range = indexDict[j][l][2] - indexDict[j][l][1]
                if range > maxRange
                    maxRange = range
                    maxInd = l
                end
            end
            indexDict[j] = [indexDict[j][maxInd]]
        end
    end
    indexDictReducedTime::Dict{Int, Tuple{Float64,Float64}} = Dict()
    for key in keys(indexDict)
        indexDictReducedTime[key] = (Float64((indexDict[key][1][1]-1)/mSR),Float64((indexDict[key][1][2]-1)/mSR))
    end

    return indexDictReducedTime
end