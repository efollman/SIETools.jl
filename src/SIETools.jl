module SIETools

using CairoMakie
using Statistics
using DataFrames
using Colors
using SomatSIE
using HDF5
using JLD2

mytheme = Theme(
    Axis = (
        yminorgridvisible = true,
        yminorticks = IntervalsBetween(5),
    ),
    Figure = (
        figure_padding = 5,
    ),
    linewidth = 0.7,
)
mythemeLatex = merge(mytheme, theme_latexfonts())
mythemeDarkLatex = merge(mythemeLatex, theme_dark())
set_theme!(mythemeLatex)

CairoMakie.activate!(type = "svg")

include("sieAccess.jl")
include("analysisTools.jl")
include("filters.jl")
include("plotTools.jl")
include("printCH.jl")
include("SIETidyr.jl")
include("markerExtractor.jl")
include("canErr.jl")
include("makeVertChartGen.jl")
include("fileTree.jl")

# Re-export the SomatSIE entry points users need to drive the new API.
export SomatSIE

# Tooling exports
export CHInfo
export tidySIE
export markExtract
export canErrFindr

export makeChart

export moving_mean
export sustained_max
export gaussian_filter

export doTree
export isSIE
export isHDF5
export isJLD2
export basicChartTree
export SIETreeToHDF5
export SIETreeToJLD2
export fileToHDF5
export fileToJLD2

end
