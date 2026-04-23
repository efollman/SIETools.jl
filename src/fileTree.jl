#=
File-tree utilities: walk a directory of SIE files and (a) generate
basic charts or (b) dump the contents into HDF5 / JLD2.

The exporters write directly off the SomatSIE 0.3 API: one HDF5/JLD2
group per channel, with per-dimension datasets and tag attributes.
=#

"""
    doTree(inpath, outpath, fun, cond)

Walk `inpath` recursively, calling `fun(root, filename, outpath, relpath)`
for every file where `cond(filename)` is true. Mirrors the input tree
under `outpath`, creating it if necessary.
"""
function doTree(inpath::String, outpath::String, fun::Function, cond::Function)
    if !isdir(inpath)
        @error "Invalid Input Filepath"
        return nothing
    end
    if !isdir(outpath)
        @warn "Output path doesnt exist creating @ $(outpath)"
        mkpath(outpath)
    end

    Ntotal = 0
    for (_, _, files) in walkdir(inpath)
        for filei in files
            cond(filei) && (Ntotal += 1)
        end
    end

    neededSpace = length(string(Ntotal)) * 2 + 3 + 3
    Ncount      = 0
    inpathL     = length(splitpath(inpath))

    for (root, _, files) in walkdir(inpath)
        for filei in files
            cond(filei) || continue
            Ncount += 1
            splitroot = splitpath(root)
            relString = length(splitroot) > inpathL ?
                joinpath(splitroot[inpathL + 1:end]...) : ""
            logCounter = "<$Ncount/$Ntotal>"
            logString  = rpad(logCounter, neededSpace, ' ') *
                         joinpath(relString, filei)
            println(logString)
            fun(root, filei, outpath, relString)
        end
    end
end

isSIE(filei::String)  = endswith(lowercase(filei), ".sie")
isHDF5(filei::String) = endswith(lowercase(filei), ".h5")
isJLD2(filei::String) = endswith(lowercase(filei), ".jld2")

"""
    basicChartTree(SIEDIR, PlotDIR)

For each SIE file under `SIEDIR`, render `makeChart` and save it as
SVG under the corresponding location in `PlotDIR`.
"""
function basicChartTree(SIEDIR::String, PlotDIR::String)
    function taskFun(filepath::String, filename::String,
                     savepath::String, relString::String)
        filenamei = replace(filename, ".sie" => "")
        srcpath   = joinpath(filepath, filenamei * ".sie")
        dstdir    = joinpath(savepath, relString)
        isdir(dstdir) || mkpath(dstdir)
        open(SomatSIE.SieFile, srcpath) do f
            fig = makeChart(f)
            save(joinpath(dstdir, filenamei * ".svg"), fig)
        end
    end
    doTree(SIEDIR, PlotDIR, taskFun, isSIE)
end

# ── HDF5 / JLD2 dump helpers ────────────────────────────────────────────

# Coerce tag values into something HDF5 attribute writes will accept.
_attrvalue(x::AbstractString)  = String(x)
_attrvalue(x::Vector{UInt8})   = x
_attrvalue(x::Real)            = x
_attrvalue(x)                  = string(x)

function _writechanneltags!(node, t::SomatSIE.Tags)
    for tag in t
        try
            HDF5.attrs(node)[SomatSIE.key(tag)] =
                _attrvalue(_parsetagvalue(SomatSIE.value(tag)))
        catch e
            @warn "skipping tag '$(SomatSIE.key(tag))' on HDF5 write" exception=e
        end
    end
end

function _writeChannelHDF5(parent, file::SomatSIE.SieFile, ch::SomatSIE.Channel)
    chName = SomatSIE.name(ch)
    g = HDF5.create_group(parent, chName)
    HDF5.attrs(g)["id"]   = SomatSIE.id(ch)
    HDF5.attrs(g)["name"] = chName
    _writechanneltags!(g, SomatSIE.tags(ch))

    for dim in SomatSIE.dimensions(ch)
        idx  = SomatSIE.index(dim)
        data = read(file, dim)
        if data isa AbstractVector{<:Real}
            dset = HDF5.create_dataset(g, "v$idx", eltype(data), (length(data),))
            HDF5.write(dset, collect(data))
            _writechanneltags!(dset, SomatSIE.tags(dim))
        elseif data isa AbstractVector{<:AbstractVector{UInt8}}
            # Variable-length byte strings — store as a vlen UInt8 dataset.
            try
                dset = HDF5.create_dataset(g, "v$idx",
                    HDF5.datatype(HDF5.VariableArray{UInt8}),
                    HDF5.dataspace((length(data),)))
                HDF5.write(dset, [Vector{UInt8}(b) for b in data])
                _writechanneltags!(dset, SomatSIE.tags(dim))
            catch e
                @warn "skipping raw dim v$idx on channel '$chName' (HDF5)" exception=e
            end
        else
            @warn "skipping dim v$idx on channel '$chName' (unsupported eltype $(eltype(data)))"
        end
    end
end

function fileToHDF5(srcpath::String, dstpath::String)
    open(SomatSIE.SieFile, srcpath) do f
        HDF5.h5open(dstpath, "w") do fid
            for ch in SomatSIE.channels(f)
                _writeChannelHDF5(fid, f, ch)
            end
        end
    end
end

"""
    SIETreeToHDF5(SIEPath, HDF5Path)

Walk `SIEPath` for `.sie` files and emit a sibling `.h5` under `HDF5Path`
mirroring the directory structure. Each HDF5 file has one group per
channel, channel/dimension tags as group/dataset attributes, and one
dataset per dimension (`v0`, `v1`, …).
"""
function SIETreeToHDF5(SIEPath::String, HDF5Path::String)
    function task(root, filei, outpath, relString)
        outfile = replace(filei, ".sie" => ".h5")
        outdir  = joinpath(outpath, relString)
        isdir(outdir) || mkpath(outdir)
        fileToHDF5(joinpath(root, filei), joinpath(outdir, outfile))
    end
    doTree(SIEPath, HDF5Path, task, isSIE)
end

# JLD2 stays Julia-native: dump a NamedTuple per channel that mirrors
# the HDF5 layout (channel tags, dim data, dim tags). Round-trips cleanly.
function _channelNT(file::SomatSIE.SieFile, ch::SomatSIE.Channel)
    dimsNT = NamedTuple[]
    for dim in SomatSIE.dimensions(ch)
        push!(dimsNT, (
            index = SomatSIE.index(dim),
            name  = SomatSIE.name(dim),
            data  = read(file, dim),
            tags  = tagdict(SomatSIE.tags(dim)),
        ))
    end
    return (
        id   = SomatSIE.id(ch),
        name = SomatSIE.name(ch),
        tags = tagdict(SomatSIE.tags(ch)),
        dims = dimsNT,
    )
end

function fileToJLD2(srcpath::String, dstpath::String)
    open(SomatSIE.SieFile, srcpath) do f
        channels = [_channelNT(f, ch) for ch in SomatSIE.channels(f)]
        JLD2.jldsave(dstpath; channels)
    end
end

"""
    SIETreeToJLD2(SIEPath, JLD2Path)

Walk `SIEPath` for `.sie` files and emit `.jld2` under `JLD2Path`. Each
output file holds a single `channels` key with a vector of NamedTuples
of `(id, name, tags, dims)` where each dim is `(index, name, data, tags)`.
"""
function SIETreeToJLD2(SIEPath::String, JLD2Path::String)
    function task(root, filei, outpath, relString)
        outfile = replace(filei, ".sie" => ".jld2")
        outdir  = joinpath(outpath, relString)
        isdir(outdir) || mkpath(outdir)
        fileToJLD2(joinpath(root, filei), joinpath(outdir, outfile))
    end
    doTree(SIEPath, JLD2Path, task, isSIE)
end
