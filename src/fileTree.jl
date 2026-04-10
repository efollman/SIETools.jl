function doTree(inpath::String,outpath::String,fun::Function,cond::Function)
    if !isdir(inpath)
        @error "Invalid Input Filepath"
        return nothing
    end

    if !isdir(outpath)
        @warn "Output path doesnt exist creating @ $(outpath)"
        mkpath(outpath)
    end

    Ntotal::UInt = 0

    for (root, dirs, files) in walkdir(inpath)
        for filei in files
            if cond(filei)
                Ntotal += 1
            end
        end
    end

    neededSpace::UInt = length(string(Ntotal))*2+3+3
    Ncount::UInt = 0
    logCounter::String = ""
    logString::String = ""
    relString::String = ""
    inpathL = length(splitpath(inpath))
    
    for (root, dirs, files) in walkdir(inpath)
        for filei in files
            if cond(filei)
                Ncount += 1
                splitroot = splitpath(root)
                if length(splitroot) > inpathL
                    relString = joinpath(splitroot[inpathL+1:end])
                else
                    relString = ""
                end
                logCounter = "<$Ncount/$Ntotal>"
                logString = rpad(logCounter, neededSpace, ' ') * joinpath(relString ,filei)
                println(logString)

                fun(root,filei,outpath,relString)
            end
        end
    end
    
end

function isSIE(filei::String)
    if filei[end-3:end] == ".sie"
        return true
    end
    return false
end

function isHDF5(filei::String)
    if filei[end-2:end] == ".h5"
        return true
    end
    return false
end

function basicChartTree(SIEDIR::String,PlotDIR::String)
    function taskFun(filepath::String,filename::String,savepath::String,relString::String)
        filenamei::String = replace(filename,".sie" => "");
        sieData::Dict{Any,Any} = parseSIE(joinpath(filepath,filenamei*".sie"));

        fig = makeChart(sieData);

        if !isdir(joinpath(savepath,relString))
            mkpath(joinpath(savepath,relString))
        end
    
        save(joinpath(savepath,relString, filenamei * ".svg"), fig);
    end
    doTree(SIEDIR,PlotDIR,taskFun,isSIE)
end