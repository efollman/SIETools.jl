#=
makeChart: stack vertical time-history plots straight from a SIE file.

Built on SomatSIE 0.3 — channels are read on demand by name; only the
selected channels (default: all) and only the requested time window
(default: full record) are pulled from disk.
=#

const _ChannelSelector = Union{AbstractString, Tuple, AbstractVector}

# Resolve a channel-id integer or a channel name string to a Channel.
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

function _readwindow(file::SomatSIE.SieFile, ch::SomatSIE.Channel,
                     plotRange::Tuple{<:Real,<:Real})
    t = collect(timevec(file, ch))
    d = Vector{Float64}(valuevec(file, ch))
    if !any(isnan, plotRange)
        cond = findall((t .>= plotRange[1]) .& (t .<= plotRange[2]))
        t = t[cond]
        d = d[cond]
    end
    return t, d
end

"""
    makeChart(file::SomatSIE.SieFile; kwargs...) -> Makie.Figure
    makeChart(path::AbstractString;   kwargs...) -> Makie.Figure

Render a vertical stack of time-history plots from `file`.

Keyword arguments:
* `plotRange::Tuple{<:Real,<:Real}` — `(tmin, tmax)` window in seconds;
  default `(NaN, NaN)` plots the whole record.
* `DSthreshold::Integer` — LTTB downsample target per axis (default 10000).
* `rowSize::Tuple{<:Integer,<:Integer}` — `(width_px, row_height_px)`.
* `heightRatio::Vector{<:Real}` — relative row heights; defaults to all 1.
* `channelsN` — vector of channel selectors. Each entry is either a name
  (`String`/`Integer`) producing one trace per row, or a `Tuple`/`Vector`
  of names producing several overlaid traces in one row. Defaults to
  every channel in the file, sorted by id.
* `cycleColor::Bool` — keep cycling palette across rows (default `true`).
* `table::DataFrame`, `tablePos::Real` — optional table inserted at row
  `tablePos` (1-based, 0 disables).
"""
function makeChart(file::SomatSIE.SieFile;
                   plotRange::Tuple{<:Real,<:Real} = (NaN, NaN),
                   DSthreshold::Integer = 10000,
                   rowSize::Tuple{<:Integer,<:Integer} = (1000, 300),
                   heightRatio::Vector{<:Real} = Float64[],
                   channelsN::Vector = [],
                   cycleColor::Bool = true,
                   table::DataFrame = DataFrame(),
                   tablePos::Real = 0)

    if DSthreshold <= 3
        @warn "invalid DSThreshold, reverting to default 10000"
        DSthreshold = 10000
    end

    # Build the row spec.
    if isempty(channelsN)
        chs = SomatSIE.channels(file)
        sort!(chs; by = SomatSIE.id)
        channelsN = [SomatSIE.name(c) for c in chs]
    end

    rowSpec = Vector{Vector{Any}}(undef, length(channelsN))
    for i in eachindex(channelsN)
        rowSpec[i] = channelsN[i] isa Union{Tuple, AbstractVector} ?
            collect(channelsN[i]) : Any[channelsN[i]]
    end

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

    for (i, sel) in enumerate(rowSpec)
        rowChs   = [_resolvechannel(file, k) for k in sel]
        firstCh  = rowChs[1]
        firstDim = SomatSIE.dimensions(firstCh)
        chUnits::String = length(firstDim) >= 2 ?
            String(tagget(SomatSIE.tags(firstDim[2]), "core:units", "")) : ""

        tableoff = (tablePos != 0 && i >= tablePos) ? 1 : 0

        axi = Axis(F[i + tableoff, 1]; title = "", ylabel = chUnits)
        rowsize!(F.layout, i, Auto(heightRatio[i]))
        push!(ax, axi)

        title = ""
        time_d = Dict{Int, Any}()
        data_d = Dict{Int, Vector{Float64}}()

        for (k, ch) in pairs(rowChs)
            chName = SomatSIE.name(ch)
            chId   = SomatSIE.id(ch)
            title = isempty(title) ?
                "Ch" * string(chId) * ": " * chName :
                title * ", Ch" * string(chId) * ": " * chName

            dims = SomatSIE.dimensions(ch)
            if length(dims) >= 1 &&
               tagget(SomatSIE.tags(dims[1]), "core:units", "") != "Seconds"
                @warn "Time units not \"Seconds\" on channel '$chName'"
            end

            t, d   = _readwindow(file, ch, plotRange)
            tx, dx = lttb(t, d, DSthreshold)
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
                label = SomatSIE.name(ch),
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

makeChart(path::AbstractString; kwargs...) =
    withfile(f -> makeChart(f; kwargs...), path)
