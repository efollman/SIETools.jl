#=
Script to iterate through SIE files collected in test, parse data and plot data.

ver:0.2.1

Author: Evan Follman
=#

plotdir::String = "TestData"
#using CairoMakie
#using GLMakie
#GLMakie.activate!();


global taskCounter::UInt = 0;

function plotTask(N::UInt,filename::String,filepath::String,savepath::String)
    

    filenamei::String = replace(filename,".sie" => "");
    SIEData::Dict{Any,Any} = parseSIE(filepath*"/"*filenamei*".sie");

    #if i == 1
    #    dataKeys = sort(collect(keys(SIEData)))
    #    for k = eachindex(dataKeys)
    #        j = dataKeys[k]
    #        println("Ch:"*string(SIEData[j]["id"])*" "*SIEData[j]["name"]);
    #    end
    #end
    
    #println("VAC RPM Max: "*string(maximum(SIEData[18]["data"][2])))
    #println("Vac P in Max: "*string(maximum(SIEData[6]["data"][2])))
    #println("Center Vaccuum Max: "*string(maximum(SIEData[14]["data"][2])))

    
    plotRange::Tuple{Float64,Float64} = (NaN,NaN)
    DST::UInt64 = 10000
    channelList = []


    fig = makeChart(SIEData; plotRange = plotRange, channelsN = channelList, DSthreshold = DST);

    #save(savepath*"/" * filenamei * ".svg", fig);
    empty!(fig);
    global taskCounter += 1;
    neededSpace::UInt = length(string(N))*2+3+3
    logCounter::String = "<"*string(taskCounter)*"/"*string(N)*">"
    logstring::String = rpad(logCounter, neededSpace, ' ') * filename
    println(logstring)
    return SIEData
end

function plotTree(filepathbase::String)
    if !isdir(filepathbase)
        @error "Invalid Filepath (tree)"
    end

    Ncounter::UInt = 0

    for (root, dirs, files) in walkdir(filepathbase)
        for filei in files
            if filei[end-3:end] == ".sie"
                Ncounter += 1
            end
        end
    end
    
    for (root, dirs, files) in walkdir(filepathbase)
        for filei in files
            if filei[end-3:end] == ".sie"
                #push!(pathcollection, root*"/"*filei)
                #push!(savepathcollection, root*"/Plots")
                if !isdir(root*"/Plots")
                    mkdir(root*"/Plots")
                end
                plotTask(Ncounter,filei,root,root*"/Plots")
            end
        end
    end
    


end

@time plotTree(plotdir)



println("Done!")