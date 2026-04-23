#=
tidySIE: long-format DataFrame view of every numeric channel in a SIE
file, suitable for plotting/grouping with DataFrames or AlgebraOfGraphics.
=#

"""
    tidySIE(file::SomatSIE.SieFile) -> DataFrame
    tidySIE(path::AbstractString)   -> DataFrame

Return a long-format `DataFrame` with columns
`Channel`, `Data`, `Time`, `Units`, `SR` — one row per sample, with
`Channel` formatted as `"<id>. <name>"`. Channels whose value dimension
isn't `Float64` (e.g. raw CAN frames) are skipped.
"""
function tidySIE(file::SomatSIE.SieFile)
    sieFrame = DataFrame("Channel" => String[], "Data" => Float64[],
                         "Time" => Float64[], "Units" => String[],
                         "SR" => Float64[])

    for ch in SomatSIE.channels(file)
        dims = SomatSIE.dimensions(ch)
        length(dims) >= 2 || continue

        data = valuevec(file, ch)
        data isa AbstractVector{<:Real} || continue

        t      = timevec(file, ch)
        dataL  = length(data)
        chName = SomatSIE.name(ch)
        chId   = SomatSIE.id(ch)
        sr     = Float64(tagget(SomatSIE.tags(ch), "core:sample_rate", NaN))
        units  = String(tagget(SomatSIE.tags(dims[2]), "core:units", ""))

        Channel = fill(string(chId, ". ", chName), dataL)
        SR_v    = fill(sr, dataL)
        Units_v = fill(units, dataL)

        append!(sieFrame, DataFrame(
            "Channel" => Channel,
            "Data"    => Vector{Float64}(data),
            "Time"    => Vector{Float64}(collect(t)),
            "Units"   => Units_v,
            "SR"      => SR_v,
        ))
    end
    return sieFrame
end

tidySIE(path::AbstractString) = withfile(tidySIE, path)
