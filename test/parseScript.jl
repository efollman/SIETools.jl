
function parseTest()
    ch = @time parseSIE("TestData/4adc17fd16e41a23004d59328d7dd6f4a3c3ee620b1921ecc0275d1e.sie");

    #@time markData = markExtract(ch,"Binary_Marker");

    for key in keys(ch)
        println(key)
    end
    return ch
end

ch = parseTest()
#=
for key in keys(ch)
    println("\nCH: $key\n")
    for inkey in keys(ch[key])
        if inkey == "data"
            println(rpad(inkey,15," ")*"Data Ommited")
            continue
        end
        println(rpad(inkey,15," ")*string(ch[key][inkey]))
    end

end
=#