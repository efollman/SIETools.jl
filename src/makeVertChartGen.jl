#=
makeChart: stack vertical time-history plots.

Channel data is represented as `ChartChannel` objects (name, id, units,
time, data). `makeChart` operates on a vector of these so the caller can
edit the data before plotting. Convenience methods accept a `SomatSIE.SieFile`
or a path and build the `ChartChannel` vector on demand using SomatSIE 0.3.
=#

const _ChannelSelector = Union{AbstractString, Tuple, AbstractVector}

"""
    ChartChannel(name, id, units, t, d)

Lightweight, mutable container holding everything `makeChart` needs to
render a single trace. `d` is a plain `Vector{Float64}` so it can be
filtered, resampled, or otherwise edited before plotting. `t` is an
`AbstractVector{Float64}` so that the common case of a uniformly-sampled
time axis can be stored as a cheap `LinRange` (no per-sample allocation).
"""
mutable struct ChartChannel
    name::String
    id::Int
    units::String
    t::AbstractVector{Float64}
    d::Vector{Float64}
end

# Resolve a channel-id integer or a channel name string to a SomatSIE.Channel.
function _resolvechannel(file::SomatSIE.SieFile, key)
    if key isa Integer
        ch = SomatSIE.findchannel(file, Int(key))
        ch === nothing && error("channel id not found: ", key)
        return ch
    elseif key isa AbstractString
        ch = findchannelbyname(file, String(key))
        ch === nothing && error("channel name not found: ", key)
        return ch
    else
        error("unsupported channel selector: ", typeof(key))
    end
end

function _channelunits(ch::SomatSIE.Channel)
    dims = SomatSIE.dimensions(ch)
    return length(dims) >= 2 ?
        String(tagget(SomatSIE.tags(dims[2]), "core:units", "")) : ""
end

function _readwindow(file::SomatSIE.SieFile, ch::SomatSIE.Channel,
                     plotRange::Tuple{<:Real,<:Real})
    tv = timevec(file, ch)
    dv = valuevec(file, ch)
    d  = dv isa Vector{Float64} ? dv : Vector{Float64}(dv)
    if any(isnan, plotRange)
        # Unwindowed: keep `tv` as-is (typically a `LinRange`, no alloc).
        return tv, d
    end
    cond = findall((tv .>= plotRange[1]) .& (tv .<= plotRange[2]))
    return tv[cond], d[cond]
end

"""
    ChartChannel(file::SomatSIE.SieFile, key; plotRange=(NaN,NaN))

Build a `ChartChannel` by reading channel `key` (name `String` or id
`Integer`) from `file`, optionally restricted to `plotRange`.
"""
function ChartChannel(file::SomatSIE.SieFile, key;
                      plotRange::Tuple{<:Real,<:Real} = (NaN, NaN))
    ch = _resolvechannel(file, key)
    dims = SomatSIE.dimensions(ch)
    if length(dims) >= 1 &&
       tagget(SomatSIE.tags(dims[1]), "core:units", "") != "Seconds"
        @warn "Time units not \"Seconds\" on channel '$(SomatSIE.name(ch))'"
    end
    t, d = _readwindow(file, ch, plotRange)
    return ChartChannel(String(SomatSIE.name(ch)), Int(SomatSIE.id(ch)),
                        _channelunits(ch), t, d)
end

"""
    chartChannels(file; channelsN=[], plotRange=(NaN,NaN)) -> Vector

Build the row-spec used by `makeChart` from `file`. Each entry of
`channelsN` is either a single name/id (one trace per row) or a tuple/
vector of names/ids (overlaid traces in a row). Defaults to every
channel in the file, sorted by id, one per row.

Returns a `Vector` whose elements are either a `ChartChannel` (one
trace) or `Vector{ChartChannel}` (multi-trace row), suitable for
passing directly to `makeChart`.
"""
function chartChannels(file::SomatSIE.SieFile;
                       channelsN::Vector = [],
                       plotRange::Tuple{<:Real,<:Real} = (NaN, NaN))
    if isempty(channelsN)
        chs = SomatSIE.channels(file)
        sort!(chs; by = SomatSIE.id)
        channelsN = [SomatSIE.name(c) for c in chs]
    end
    rows = Vector{Any}(undef, length(channelsN))
    for i in eachindex(channelsN)
        sel = channelsN[i]
        if sel isa Union{Tuple, AbstractVector} && !(sel isa AbstractString)
            rows[i] = [ChartChannel(file, k; plotRange = plotRange) for k in sel]
        else
            rows[i] = ChartChannel(file, sel; plotRange = plotRange)
        end
    end
    return rows
end

chartChannels(path::AbstractString; kwargs...) =
    withfile(f -> chartChannels(f; kwargs...), path)

# Normalize a single row entry into Vector{ChartChannel}.
_rowchannels(x::ChartChannel) = ChartChannel[x]
_rowchannels(x::AbstractVector{ChartChannel}) = collect(x)
function _rowchannels(x::AbstractVector)
    all(e -> e isa ChartChannel, x) ||
        error("row entries must be ChartChannel or Vector{ChartChannel}")
    return ChartChannel[e for e in x]
end
function _rowchannels(x::Tuple)
    all(e -> e isa ChartChannel, x) ||
        error("row entries must be ChartChannel or Vector{ChartChannel}")
    return ChartChannel[e for e in x]
end

"""
    makeChart(channels::AbstractVector; kwargs...) -> Makie.Figure
    makeChart(file::SomatSIE.SieFile;    kwargs...) -> Makie.Figure
    makeChart(path::AbstractString;      kwargs...) -> Makie.Figure

Render a vertical stack of time-history plots.

The primary method takes a vector of rows. Each row is either a
`ChartChannel` (one trace) or a `Vector{ChartChannel}` (overlaid traces
on the same axis). The `SieFile`/path methods build the row vector via
`chartChannels` and forward to the primary method, allowing callers to
edit channel data between extraction and plotting.

Keyword arguments:
* `DSthreshold::Integer` — LTTB downsample target per axis (default 10000).
* `rowSize::Tuple{<:Integer,<:Integer}` — `(width_px, row_height_px)`.
* `heightRatio::Vector{<:Real}` — relative row heights; defaults to all 1.
* `cycleColor::Bool` — keep cycling palette across rows (default `true`).
* `table::DataFrame`, `tablePos::Real` — optional table inserted at row
  `tablePos` (1-based, 0 disables).

`SieFile`/path methods additionally accept:
* `plotRange::Tuple{<:Real,<:Real}` — `(tmin, tmax)` window in seconds;
  default `(NaN, NaN)` plots the whole record.
* `channelsN::Vector` — selectors as described in `chartChannels`.
"""
function makeChart(channels::AbstractVector;
                   DSthreshold::Integer = 10000,
                   rowSize::Tuple{<:Integer,<:Integer} = (1000, 300),
                   heightRatio::Vector{<:Real} = Float64[],
                   cycleColor::Bool = true,
                   table::DataFrame = DataFrame(),
                   tablePos::Real = 0)

    if DSthreshold <= 3
        @warn "invalid DSThreshold, reverting to default 10000"
        DSthreshold = 10000
    end

    rowSpec = [_rowchannels(r) for r in channels]
    isempty(rowSpec) && error("makeChart: no channels supplied")

    if isempty(heightRatio)
        heightRatio = fill(1.0, length(rowSpec))
    end
    while length(heightRatio) < length(rowSpec)
        push!(heightRatio, 1.0)
    end
    heightRatio = heightRatio[1:length(rowSpec)]

    N        = length(rowSpec)
    plotW    = rowSize[1]
    rowH     = rowSize[2]
    F        = Figure(size = (plotW, round(Int, rowH * sum(heightRatio))))
    ax       = Axis[]
    colori   = 1
    colorFlag = false

    for (i, rowChs) in enumerate(rowSpec)
        firstCh  = rowChs[1]
        chUnits  = firstCh.units

        tableoff = (tablePos != 0 && i >= tablePos) ? 1 : 0

        axi = Axis(F[i + tableoff, 1]; title = "", ylabel = chUnits)
        rowsize!(F.layout, i, Auto(heightRatio[i]))
        push!(ax, axi)

        title = ""
        time_d = Dict{Int, Vector{Float64}}()
        data_d = Dict{Int, Vector{Float64}}()

        for (k, ch) in pairs(rowChs)
            title = isempty(title) ?
                "Ch" * string(ch.id) * ": " * ch.name :
                title * ", Ch" * string(ch.id) * ": " * ch.name

            tx, dx = lttb(ch.t, ch.d, DSthreshold)
            time_d[k] = tx
            data_d[k] = dx
        end
        axi.title = title

        length(rowChs) > 1 && (colorFlag = true)
        (cycleColor == false || colorFlag) || (colori = 1)
        length(rowChs) == 1 && (colorFlag = false)

        for (k, ch) in pairs(rowChs)
            lines!(axi, time_d[k], data_d[k];
                color = Cycled(colori),
                label = ch.name,
            )
            colori += 1
        end

        if i == N
            axi.xlabel = "Time (Seconds)"
        end

        if length(rowChs) > 1
            Legend(F[i, 2], axi)
        end
        linkxaxes!(ax[1], axi)

        axi.yticks = LinearTicks(10)
        axi.xticks = LinearTicks(20)
    end

    if tablePos != 0
        axt = Axis(F[tablePos, 1])
        hidedecorations!(axt)
        render_table(axt, table)
    end

    rowgap!(F.layout, 5)
    return F
end

function makeChart(file::SomatSIE.SieFile;
                   plotRange::Tuple{<:Real,<:Real} = (NaN, NaN),
                   channelsN::Vector = [],
                   kwargs...)
    rows = chartChannels(file; channelsN = channelsN, plotRange = plotRange)
    return makeChart(rows; kwargs...)
end

makeChart(path::AbstractString; kwargs...) =
    withfile(f -> makeChart(f; kwargs...), path)
