#=
CHInfo: a one-row-per-channel summary of a SIE file's metadata,
built directly off the SomatSIE 0.3 high-level API.
=#

"""
    CHInfo(file::SomatSIE.SieFile) -> DataFrame
    CHInfo(path::AbstractString)   -> DataFrame

Return a `DataFrame` describing every channel in `file`: id, name,
description, label, value-dim units, time-dim units, sample rate,
datamode type, and number of samples (rows in dim 1, when present).
Sorted by channel id.
"""
function CHInfo(file::SomatSIE.SieFile)
    rows = NamedTuple[]
    for ch in SomatSIE.channels(file)
        info = chinfo(ch)
        dims = SomatSIE.dimensions(ch)

        nsamples = 0
        if length(dims) >= 2
            SomatSIE.spigot(file, ch) do s
                for out in s
                    nsamples += SomatSIE.numrows(out)
                end
            end
        end

        push!(rows, (
            id          = info.id,
            name        = info.name,
            description = info.description,
            label       = info.label,
            units       = info.units,
            timeunits   = info.timeunits,
            sr          = info.sr,
            datamode    = info.datamode,
            samples     = nsamples,
        ))
    end
    df = DataFrame(rows)
    sort!(df, :id)
    return df
end

CHInfo(path::AbstractString) = withfile(CHInfo, path)
