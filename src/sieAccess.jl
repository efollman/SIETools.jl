#=
Internal helpers that bridge SomatSIE 0.3's high-level API to the
plotting / analysis / IO modules in this package.

Conventions:
* `chinfo(ch)` returns a small NamedTuple of frequently-used identifiers.
* `tagdict(x)` materializes a tags collection into a `Dict{String,Any}`,
  parsing string values into Int/Float64 when possible (sample rates,
  ranges, etc. arrive as strings on the wire).
* `timevec(file, ch)` returns a `LinRange` for time-history channels (cheap,
  derived from `core:sample_rate` + `core:start_time`) or falls back to
  `read(file, dim0)` for any other case.
* `valuevec(file, ch)` returns the sample data for dimension 1.
* `findchannelbyname(file, name)` looks up a channel by its display name.
=#

const _TagsCollection = SomatSIE.Tags

_parsetagvalue(s::AbstractString) = let
    out = tryparse(Int, s)
    out !== nothing ? out :
        (out = tryparse(Float64, s); out !== nothing ? out : String(s))
end
_parsetagvalue(b::Vector{UInt8}) = b
_parsetagvalue(x) = x

function tagdict(t::_TagsCollection)
    d = Dict{String,Any}()
    for tag in t
        v = SomatSIE.value(tag)
        d[SomatSIE.key(tag)] = _parsetagvalue(v)
    end
    return d
end

# Quick scalar tag access without materializing the whole dict.
function tagget(t::_TagsCollection, key::AbstractString, default = nothing)
    haskey(t, key) || return default
    v = SomatSIE.value(t[key])
    return _parsetagvalue(v)
end

"""
    chinfo(ch::SomatSIE.Channel) -> NamedTuple

Pull the most commonly used scalar fields off a channel: id, name,
sample rate, datamode type, value-dim units, time-dim units, label,
description.
"""
function chinfo(ch::SomatSIE.Channel)
    chTags = SomatSIE.tags(ch)
    dims   = SomatSIE.dimensions(ch)

    dim0Tags = isempty(dims) ? nothing : SomatSIE.tags(dims[1])
    dim1Tags = length(dims) >= 2 ? SomatSIE.tags(dims[2]) : nothing

    return (
        id          = SomatSIE.id(ch),
        name        = SomatSIE.name(ch),
        ndims       = length(dims),
        sr          = tagget(chTags, "core:sample_rate", missing),
        datamode    = tagget(chTags, "somat:datamode_type", missing),
        description = tagget(chTags, "core:description", missing),
        label       = tagget(chTags, "core:label",
                       dim1Tags === nothing ? missing :
                           tagget(dim1Tags, "core:label", missing)),
        units       = dim1Tags === nothing ? missing :
                          tagget(dim1Tags, "core:units", missing),
        timeunits   = dim0Tags === nothing ? missing :
                          tagget(dim0Tags, "core:units", missing),
    )
end

"""
    timevec(file, ch) -> AbstractVector{Float64}

Return the time axis for `ch`. For sequential time-history channels
this is a cheap `LinRange` derived from `core:sample_rate`; otherwise
the dim-0 data is read from disk.
"""
function timevec(file::SomatSIE.SieFile, ch::SomatSIE.Channel)
    chTags = SomatSIE.tags(ch)
    dims   = SomatSIE.dimensions(ch)
    isempty(dims) && return Float64[]

    dim0     = dims[1]
    dim0Tags = SomatSIE.tags(dim0)

    if tagget(chTags, "somat:datamode_type", "") == "time_history" &&
       tagget(dim0Tags, "core:units", "") == "Seconds" &&
       haskey(chTags, "core:sample_rate")

        sr   = Float64(tagget(chTags, "core:sample_rate"))
        # libsie still reads dim0 to learn length & start; but reading the
        # whole vector is the only general way to get N without spinning
        # up the spigot ourselves. The cost is paid once at open.
        t0 = read(file, dim0)
        len = length(t0)
        len == 0 && return LinRange(0.0, 0.0, 0)
        start = Float64(first(t0))
        return LinRange(start, start + (len - 1) / sr, len)
    end

    return read(file, dim0)
end

"""
    valuevec(file, ch) -> Vector{Float64} | Vector{Vector{UInt8}}

Read the value dimension (dim index 1) for `ch`.
"""
function valuevec(file::SomatSIE.SieFile, ch::SomatSIE.Channel)
    dims = SomatSIE.dimensions(ch)
    length(dims) >= 2 || error("channel '", SomatSIE.name(ch),
                               "' has no value dimension")
    return read(file, dims[2])
end

"""
    findchannelbyname(file, name) -> Channel | nothing
"""
function findchannelbyname(file::SomatSIE.SieFile, name::AbstractString)
    for ch in SomatSIE.channels(file)
        SomatSIE.name(ch) == name && return ch
    end
    return nothing
end

"""
    withfile(f, src)

Internal: accept either a `SieFile` (used directly) or a path string
(opened/closed for the duration of the call).
"""
withfile(f, file::SomatSIE.SieFile) = f(file)
function withfile(f, path::AbstractString)
    open(SomatSIE.SieFile, String(path)) do file
        f(file)
    end
end
