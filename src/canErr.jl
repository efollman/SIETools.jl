#=
J1939 DM1 / extended-DM1 fault decoder for CAN data captured into a
SIE file's raw-frame channel. Driven directly by SomatSIE 0.3.

Public entry point: `canErrFindr(file, channelName)`.
=#

"""
    canErrFindr(file::SomatSIE.SieFile, chName::AbstractString) -> DataFrame
    canErrFindr(path::AbstractString,   chName::AbstractString) -> DataFrame

Decode J1939 DM1 (single-frame, PGN 0xFECA) and extended-DM1
(BAM-segmented, PGN 0xECFF -> 0xEBFF) fault frames from the raw CAN
channel `chName`. Returns one row per (PGN, SA, LS, SPN, FMI, OC),
duplicates collapsed to their earliest occurrence time.
"""
function canErrFindr(file::SomatSIE.SieFile, chName::AbstractString)
    ch = findchannelbyname(file, String(chName))
    ch === nothing && error("channel not found: ", chName)

    rawFrames = valuevec(file, ch)
    rawFrames isa AbstractVector{<:AbstractVector{UInt8}} ||
        error("channel '", chName,
              "' value dim is not raw CAN frames (got ", typeof(rawFrames), ")")

    t = collect(timevec(file, ch))

    CANID, CANFrame = niceCan(Vector{Vector{UInt8}}(rawFrames))
    t, CANID, CANFrame = CANErrFilt(t, CANID, CANFrame)

    pl, plID, t = CANErrPayloads(t, CANID, CANFrame)

    return removeDupes(InterpPL(pl, plID, t))
end

canErrFindr(path::AbstractString, chName::AbstractString) =
    withfile(f -> canErrFindr(f, chName), path)

function niceCan(rawCan::Vector{Vector{UInt8}})
    CANID    = UInt32[]
    CANFrame = Vector{Vector{UInt8}}()
    for i in eachindex(rawCan)
        push!(CANID, reinterpret(UInt32, reverse(rawCan[i][1:4]))[1] & 0x1fffffff)
        push!(CANFrame, rawCan[i][5:end])
    end
    return CANID, CANFrame
end

function CANErrFilt(time, CANID, CANFrame)
    CANIDout    = UInt32[]
    CANFrameout = Vector{Vector{UInt8}}()
    timeout     = Float64[]
    for i in eachindex(CANID)
        if ((0x00FFFF00 & CANID[i]) ⊻ 0x00FECA00) == 0 ||
           ((0x00FFFF00 & CANID[i]) ⊻ 0x00ECFF00) == 0 ||
           ((0x00FFFF00 & CANID[i]) ⊻ 0x00EBFF00) == 0
            push!(CANIDout, CANID[i])
            push!(CANFrameout, CANFrame[i])
            push!(timeout, time[i])
        end
    end
    return timeout, CANIDout, CANFrameout
end

function CANErrPayloads(time, CANID, CANFrame)
    payloads     = Vector{Vector{UInt8}}()
    payloadsID   = UInt32[]
    exframedata  = UInt8[]
    timeOut      = Float64[]
    i = 1
    while i <= length(CANID)
        if ((0x00FFFF00 & CANID[i]) ⊻ 0x00FECA00) == 0
            push!(payloads, CANFrame[i][1:6])
            push!(payloadsID, CANID[i])
            push!(timeOut, time[i])
        end
        if ((0x00FFFF00 & CANID[i]) ⊻ 0x00ECFF00) == 0
            if reinterpret(UInt16, [CANFrame[i][6]; CANFrame[i][7]])[1] == 0xFECA
                CANFrame[i][1] != 0x20 && @warn "Not BAM?"
                frames    = CANFrame[i][4]
                currFrame = 1
                exframedata = UInt8[]
                LS = UInt8[]
                j = i + 1
                while j <= length(CANID)
                    if CANID[j] == CANID[i]
                        @warn "Unexpected new multiframe before last finished: time=$(time[j]) id=0x$(string(CANID[j],base=16)) frame=0x$(bytes2hex(CANFrame[j])) next index expected=$currFrame length expected=$frames"
                        break
                    end
                    if ((CANID[i] & 0x00ffffff) - 0x00010000) == (CANID[j] & 0x00ffffff)
                        if CANFrame[j][1] == currFrame
                            currFrame += 1
                            if CANFrame[j][1] == 1
                                LS    = CANFrame[j][2:3]
                                start = 4
                            else
                                start = 2
                            end
                            for k = start:length(CANFrame[j])
                                push!(exframedata, CANFrame[j][k])
                            end
                            if CANFrame[j][1] == frames
                                exframedata = exframedata[1:(CANFrame[i][2]-2)]
                                break
                            elseif j == length(CANID)
                                @warn "End of file before multi frame assembled"
                                exframedata = UInt8[]
                                break
                            end
                        else
                            @warn "Index in multi frame desync"
                            exframedata = UInt8[]
                            break
                        end
                    end
                    j += 1
                end

                if length(exframedata) >= 4
                    for b = 0:((length(exframedata) ÷ 4) - 1)
                        push!(payloads, [LS; exframedata[(b*4)+1:(b*4)+4]])
                        push!(payloadsID, CANID[i])
                        push!(timeOut, time[i])
                    end
                end
            end
        end
        i += 1
    end
    return payloads, payloadsID, timeOut
end

function InterpPL(pl, plID, t)
    TIME = Float64[]
    PGN  = String[]
    SA   = String[]
    LS   = String[]
    SPN  = UInt32[]
    FMI  = UInt8[]
    OC   = UInt8[]

    for (ple, plIDe, te) in zip(pl, plID, t)
        currSPN = reinterpret(UInt32,
            [ple[3]; ple[4]; ((ple[5] & 0b11100000) >> 5); 0x00])[1]
        currSPN == 0 && continue

        push!(TIME, te)
        push!(PGN,  string(((plIDe & 0xFFFF00) >> 8), base = 16))
        push!(SA,   "0x$(string((plIDe & 0xFF), base = 16))")
        push!(LS,   "0x$(string(reinterpret(UInt16, [ple[1]; ple[2]])[1], base = 16))")
        push!(SPN,  currSPN)
        push!(FMI,  ple[5] & 0b00011111)
        push!(OC,   ple[6] & 0b01111111)
        if ple[6] & 0b10000000 > 0
            @warn "CM bit = 1, older SPN encoding? SPN=$currSPN time=$te payload=0x$(bytes2hex(ple))"
        end
    end

    return DataFrame("Time" => TIME, "PGN" => PGN, "SA" => SA,
                     "LS" => LS, "SPN" => SPN, "FMI" => FMI, "OC" => OC)
end

function removeDupes(eF)
    (h, _) = size(eF)
    eF = sort(eF, :Time)
    i = h
    while i >= 1
        j = i - 1
        while j >= 1
            if eF[j, 5] == eF[i, 5] && eF[j, 6] == eF[i, 6] &&
               eF[i, 3] == eF[j, 3] && eF[i, 7] == eF[j, 7]
                eF[i, 1] = minimum([eF[j, 1], eF[i, 1]])
                delete!(eF, j)
                i -= 1
            end
            j -= 1
        end
        i -= 1
    end
    return sort(eF, :Time)
end
