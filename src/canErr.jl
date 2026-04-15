function canErrFindr(sieCH::Dict)
    CANID,CANFrame = niceCan(Vector{Vector{UInt8}}(sieCH["v1"]))
    t = sieCH["v0"]
    t, CANID, CANFrame = CANErrFilt(t,CANID,CANFrame)

    pl, plID, t = CANErrPayloads(t,CANID,CANFrame)

    ErrFrame = InterpPL(pl,plID,t)
    eF = removeDupes(ErrFrame)
    return eF
end

function niceCan(rawCan::Vector{Vector{UInt8}})
    CANID::Vector{UInt32} = []
    CANFrame::Vector{Vector{UInt8}} = []
    for i = 1:length(rawCan)
        push!(CANID,reinterpret(UInt32,reverse(rawCan[i][1:4]))[1] & 0x1fffffff)
        push!(CANFrame,rawCan[i][5:end])
    end
    return CANID, CANFrame
end

function CANErrFilt(time,CANID,CANFrame)
    CANIDout = []
    CANFrameout = []
    timeout = []
    for i in eachindex(CANID)
        if ((0x00FFFF00 & CANID[i]) ⊻ 0x00FECA00) == 0 || ((0x00FFFF00 & CANID[i]) ⊻ 0x00ECFF00) == 0 || ((0x00FFFF00 & CANID[i]) ⊻ 0x00EBFF00) == 0
            push!(CANIDout,CANID[i])
            push!(CANFrameout,CANFrame[i])
            push!(timeout,time[i])
        end
    end

    return timeout, CANIDout, CANFrameout
end

function CANErrPayloads(time,CANID,CANFrame)
    payloads::Vector{Vector{UInt8}} = []
    payloadsID::Vector{UInt32} =[]
    exframedata::Vector{UInt8} = []
    timeOut::Vector{Float64} = []
    i = 1
    while i <= length(CANID)
        if ((0x00FFFF00 & CANID[i]) ⊻ 0x00FECA00) == 0
            push!(payloads,CANFrame[i][1:6])
            push!(payloadsID,CANID[i])
            push!(timeOut,time[i])
        end
        if ((0x00FFFF00 & CANID[i]) ⊻ 0x00ECFF00) == 0
            if reinterpret(UInt16,[CANFrame[i][6];CANFrame[i][7]])[1] == 0xFECA
                if CANFrame[i][1] != 0x20
                    @warn "Not BAM?"
                end
                frames = CANFrame[i][4]
                currFrame = 1
                exframedata = []
                j = i+1
                LS = 0
                while j <= length(CANID)
                    if CANID[j] == CANID[i]
                        @warn "Unxpected new multiframe before last finished: time: $(time[j]) id: 0x$(string(CANID[j],base=16)) frame: 0x$(bytes2hex(CANFrame[j])) next index expected: $currFrame length expected: $frames"
                        break
                    end
                    if ((CANID[i] & 0x00ffffff)-0x00010000) == (CANID[j] & 0x00ffffff) #converts original header from EC to EB

                        if CANFrame[j][1] == currFrame #index check

                            currFrame +=1
                            if CANFrame[j][1] == 1
                                LS = CANFrame[j][2:3]
                                start = 4
                            else
                                start = 2
                            end

                            for k = start:length(CANFrame[j])
                                push!(exframedata,CANFrame[j][k])
                            end
                            if CANFrame[j][1] == frames
                                currFrame = 1
                                exframedata = exframedata[1:(CANFrame[i][2]-2)]
                                #println("$(CANFrame[i][2]) - $(length(exframedata))")
                                break 
                            elseif j == length(CANID)
                                @warn "End of file before multi frame assembled"
                                exframedata = []
                                break
                            end
                        else
                            @warn "Index in multi frame desync"
                            exframedata = []
                            break
                        end
                    end
                    j+=1
                end

                if length(exframedata) >= 4
                    for b = 0:((length(exframedata) ÷ 4)-1)
                        push!(payloads,[LS;exframedata[(b*4)+1:(b*4)+4]])
                        push!(payloadsID,CANID[i])
                        push!(timeOut,time[i])
                    end
                end

            end
        end
        i += 1
    end

    return payloads, payloadsID, timeOut
    
end

function InterpPL(pl, plID, t)
    #ErrFrame = DataFrame()

    TIME::Vector{Float64} = []

    PGN::Vector{String} = []
    SA::Vector{String} = []

    LS::Vector{String} = []
    SPN::Vector{UInt32} = []
    FMI::Vector{UInt8} = []
    OC::Vector{UInt8} = []

    for (ple,plIDe,te) in zip(pl,plID,t)

        currSPN = reinterpret(UInt32,[ple[3];ple[4];((ple[5] & 0b11100000) >> 5);0x00])[1]
        if currSPN != 0

            push!(TIME, te)
            push!(PGN, string(((plIDe & 0xFFFF00) >> 8),base=16))
            push!(SA, string("0x$(string((plIDe & 0xFF),base = 16))"))
            
            push!(LS, "0x$(string(reinterpret(UInt16,[ple[1];ple[2]])[1],base=16))")
            push!(SPN, currSPN)
            push!(FMI, ple[5] & 0b00011111)
            push!(OC, ple[6] & 0b01111111)
            if ple[6] & 0b10000000 > 0
                @warn "CM bit = 1, Older SPN encoding version? SPN:$currSPN, Time:$te, Payload:0x$(bytes2hex(ple))"
            end
        end
    end

    ErrFrame = DataFrame("Time" => TIME, "PGN" => PGN, "SA" => SA, "LS" => LS, "SPN" => SPN, "FMI" => FMI, "OC" => OC)
    return ErrFrame
end

function removeDupes(eF)
    (h,_) = size(eF)
    eF = sort(eF,:Time)
    i = h
    while i >= 1
        j = i-1
        while j >= 1
            if eF[j,5] == eF[i,5] && eF[j,6] == eF[i,6] && eF[i,3] == eF[j,3] && eF[i,7] == eF[j,7]
                eF[i,1] = minimum([eF[j,1],eF[i,1]]) #Keep Earliest Time
                delete!(eF,j)

                i-=1
            end
            j -= 1
        end
        i -= 1
    end
    eF = sort(eF,:Time)
    return eF
end