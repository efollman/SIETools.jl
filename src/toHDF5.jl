#Untested/ In progress

function dictToHDF5(filepath::String,dict::Dict)

    function write_dict(groupname, dict::Dict, fid)
        g = create_group(fid, groupname) 
        for (key, value) in dict

            keyname = groupname * "/" * string(key)
            
            if typeof(value) <: Dict # nested, recurse
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
        write_dict("sieData",dict,fid)
    end

    return nothing
end



function SIETreeToHDF5(SIEPath::String,HDF5Path::String)
    function SIEtoHDF5Task(root,filei,outpath,relString)
        outfile = replace(filei,".sie" => "") * ".h5";
        dictToHDF5(joinpath(outpath,relString,outfile),parseSIE(joinpath(root,filei)))
    end
    doTree(SIEPath,HDF5Path,SIEtoHDF5Task,isSIE)
    return nothing
end