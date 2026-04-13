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
    if length(filei) > 3 && filei[end-3:end] == ".sie"
        return true
    end
    return false
end

function isHDF5(filei::String)
    if length(filei) > 2 && filei[end-2:end] == ".h5"
        return true
    end
    return false
end

function isJLD2(filei::String)
    if length(filei) > 4 && filei[end-4:end] == ".jld2"
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

#Errors on raw data VoV UInt8
function dictToHDF5(filepath::String,dict::Dict)


    function write_dict(groupname, dict::Dict, fid)
        if !isempty(groupname)
            g = create_group(fid, groupname) 
        end
        for (key, value) in dict

            keyname = groupname * "/" * string(key)
            
            if typeof(value) <: Dict # nested, recurse
                if string(key) == "tags"
                    for (tag,tagV) in value
                        if typeof(tagV) <: Dict #need to fix for xform tags / dim tags
                            continue
                        end
                        attrs(fid[groupname])[string(tag)] = tagV
                    end
                    continue

                end
                write_dict(keyname, value,fid)
                continue
            elseif isa(value,LinRange)
                tempDict::Dict = Dict()
                tempDict["first"] = first(value)
                tempDict["step"] = step(value)
                tempDict["last"] = last(value)
                write_dict(keyname,tempDict,fid)
                continue
            elseif isa(value,Tuple)
                value = collect(value)
            elseif isa(value, Type)
                value = string(value)
            end
            write(fid,keyname,value)
        end
    end

    h5open(filepath, "w") do fid
        write_dict("",dict,fid)
    end

    return nothing
end

function SIETreeToHDF5(SIEPath::String,HDF5Path::String)
    function SIEtoHDF5Task(root,filei,outpath,relString)
        outfile = replace(filei,".sie" => ".h5");
        if !isdir(joinpath(outpath,relString))
            mkpath(joinpath(outpath,relString))
        end
        dictToHDF5(joinpath(outpath,relString,outfile),parseSIE(joinpath(root,filei)))
    end
    doTree(SIEPath,HDF5Path,SIEtoHDF5Task,isSIE)
    return nothing
end

function SIETreeToJLD2(SIEPath::String,JLD2Path::String)
    function SIEtoJLD2Task(root,filei,outpath,relString)
        outfile = replace(filei,".sie" => ".jld2");
        if !isdir(joinpath(outpath,relString))
            mkpath(joinpath(outpath,relString))
        end

        sieD = parseSIE(joinpath(root,filei))

        jldsave(joinpath(outpath,relString,outfile); sieD)
        
    end
    doTree(SIEPath,JLD2Path,SIEtoJLD2Task,isSIE)
    return nothing
end