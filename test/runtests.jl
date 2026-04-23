using SIETools
using SomatSIE
using DataFrames
using Statistics
using Test
import Makie

const TESTDATA = joinpath(@__DIR__, "TestData")

# Pick a stable sample file used across tests.
const SAMPLE = joinpath(TESTDATA,
    "4adc17fd16e41a23004d59328d7dd6f4a3c3ee620b1921ecc0275d1e.sie")

@testset "SIETools.jl" begin
    @test isfile(SAMPLE)

    @testset "open + iterate" begin
        n = open(SomatSIE.SieFile, SAMPLE) do f
            length(SomatSIE.channels(f))
        end
        @test n > 0
    end

    @testset "CHInfo" begin
        df = CHInfo(SAMPLE)
        @test df isa DataFrame
        @test nrow(df) > 0
        @test names(df) == ["id", "name", "description", "label",
                            "units", "timeunits", "sr", "datamode", "samples"]
        @test issorted(df.id)
        @test all(df.samples .>= 0)
    end

    @testset "tidySIE" begin
        df = tidySIE(SAMPLE)
        @test df isa DataFrame
        @test nrow(df) > 0
        @test Set(names(df)) == Set(["Channel", "Data", "Time", "Units", "SR"])
        @test eltype(df.Data) == Float64
        @test eltype(df.Time) == Float64
    end

    @testset "makeChart" begin
        # Subset of channels to keep this quick.
        open(SomatSIE.SieFile, SAMPLE) do f
            chs   = SomatSIE.channels(f)
            sort!(chs; by = SomatSIE.id)
            picks = [SomatSIE.name(c) for c in chs[1:min(3, length(chs))]]
            fig = makeChart(f; channelsN = picks, DSthreshold = 2000)
            @test fig isa Makie.Figure
        end
    end

    @testset "markExtract" begin
        # Locate a marker-style channel by name; skip if absent.
        markName = open(SomatSIE.SieFile, SAMPLE) do f
            for c in SomatSIE.channels(f)
                n = lowercase(SomatSIE.name(c))
                if occursin("mark", n)
                    return SomatSIE.name(c)
                end
            end
            return nothing
        end
        if markName === nothing
            @info "no marker channel in sample; skipping markExtract"
        else
            ext = markExtract(SAMPLE, markName)
            @test ext isa Dict
            @test haskey(ext, markName) || !isempty(ext)
        end
    end

    @testset "HDF5 / JLD2 round trip" begin
        outdir = mktempdir()
        try
            h5path = joinpath(outdir, "out.h5")
            j2path = joinpath(outdir, "out.jld2")
            fileToHDF5(SAMPLE, h5path)
            fileToJLD2(SAMPLE, j2path)
            @test isfile(h5path)
            @test isfile(j2path)
            @test filesize(h5path) > 0
            @test filesize(j2path) > 0
        finally
            rm(outdir; recursive = true, force = true)
        end
    end

    @testset "doTree / SIETreeToHDF5" begin
        outdir = mktempdir()
        try
            SIETreeToHDF5(TESTDATA, outdir)
            # At least one .h5 should have been emitted somewhere under outdir.
            found = false
            for (_, _, files) in walkdir(outdir)
                any(isHDF5, files) && (found = true; break)
            end
            @test found
        finally
            rm(outdir; recursive = true, force = true)
        end
    end

    @testset "analysis helpers" begin
        x = collect(1.0:100.0)
        @test moving_mean(x, 5)[1] ≈ mean(x[1:5])
        @test sustained_max(x, 10) > 0
        @test length(gaussian_filter(x, 10)) > 0
    end
end
