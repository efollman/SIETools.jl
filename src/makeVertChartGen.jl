#=
Work in progress script to batch proccess parsed sie data and plot channels, currently it is semi-configurable through optional paramaters.
A lot of things are still hardcoded however, working on fully generalizing
=#


function makeChart(ch::Dict; plotRange::Tuple{<:Real, <:Real} = (NaN,NaN), DSthreshold::Integer = 10000, rowSize::Tuple{<:Integer,<:Integer} = (1000,300), heightRatio::Vector{<:Real} = Vector{Float64}([]), channelsN::Vector = [], cycleColor::Bool = true, table::DataFrame = DataFrame(), tablePos::Real = 0)

    if DSthreshold <= 3
        @warn "invalid DSThreshold, reverting to default 10000"
        DSthreshold = 10000
    end
    
    if isempty(channelsN)
        channelsNKeys = collect(keys(ch))
        chids = []
        chPerm = []
        for key in channelsNKeys
            push!(chids,ch[key]["id"])
        chPerm = sortperm(chids)
        end
        for i in chPerm
            push!(channelsN,channelsNKeys[i])
        end
    end
    chKeys::Vector{Tuple} = []
    for i in eachindex(channelsN)
        if typeof(channelsN[i]) == String
            push!(chKeys,(channelsN[i],))
        else
            push!(chKeys,channelsN[i])
        end
    end

    if isempty(heightRatio)
        heightRatio = fill(1,length(channelsN))
    end

    while length(heightRatio) < length(channelsN)
        push!(heightRatio,1)
    end

    heightRatio = heightRatio[1:length(channelsN)]
    colorFlag::Bool = false

    #println(chKeys)
    ##add sort by channel num
    N::UInt = length(chKeys)
    plotWidth::UInt = rowSize[1]
    rowHeight::UInt = rowSize[2]
    F = Figure(size = (plotWidth, round(rowHeight*sum(heightRatio))))
    ax = []
    colori::UInt = 1
    for i in eachindex(chKeys)
        chiV = chKeys[i]
        chUnits::String = ""

        if haskey(ch[chiV[1]], "units")
            chUnits = ch[chiV[1]]["units"]
        end
        if tablePos != 0 && i >= tablePos
            tableoff = 1
        else
            tableoff = 0
        end
        name::String = ""
        axi = Axis(F[i+tableoff,1];
            title = name, 
            ylabel = chUnits,
            #xticks = WilkinsonTicks(10),
            #yticks = WilkinsonTicks(10),
            #width = plotWidth,
            #height = rowHeight*heightRatio[i],
        )
        rowsize!(F.layout,i,Auto(heightRatio[i]))
        push!(ax,axi)
        time::Dict{UInt, Union{Vector{<:Real},LinRange}} = Dict()
        data::Dict{UInt, Vector{<:Real}} = Dict()
        #Threads.@threads 
        for k in eachindex(chiV)
            chi = chiV[k]
            if name == ""
                name = name*"Ch"*string(ch[chi]["id"])*": "*chi
            else
                name = name*", "*"Ch"*string(ch[chi]["id"])*": "*chi
            end

            if ch[chi]["timeunits"] != "Seconds"
                @warn "Time units not \"Seconds\""
            end

            ax[i].title = name
            time[k] = ch[chi]["time"]
            data[k] = ch[chi]["data"]

            if plotRange !== (NaN,NaN)
                lower_bound = plotRange[1]
                upper_bound = plotRange[2]
                condition = findall((time[k] .>= lower_bound) .& (time[k] .<= upper_bound))
                time[k] = time[k][condition]
                data[k] = data[k][condition]
            end

            

            time[k],data[k] = lttb(time[k],data[k],DSthreshold);

        end

        if length(chiV) > 1
            colorFlag = true
        end

        if cycleColor == false || colorFlag == true
            colori = 1
        end

        if length(chiV) == 1
            colorFlag = false
        end

        for k in eachindex(chiV)
            lines!(ax[i], time[k], data[k];
                color = Cycled(colori),
                label = chiV[k],
                #rasterize = 1,
            )
            colori += 1
        end

        if i == N
            ax[i].xlabel = ("Time (Seconds)") # change to pull from tags in case it isnt seconds some day
        end
        
        if length(chiV) > 1
            #axislegend(framevisible = false, position = :lt)
            Legend(F[i,2],ax[i])
        end
        linkxaxes!(ax[1],axi)

        axi.yticks = LinearTicks(10)
        axi.xticks = LinearTicks(20)

    end

    if tablePos != 0
        axt = Axis(F[tablePos,1])
        hidedecorations!(axt)
        render_table(axt,table)
        
    end

    rowgap!(F.layout,5)
    return F
    empty!(F)
end