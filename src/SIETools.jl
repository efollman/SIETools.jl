module SIETools

using CairoMakie
using Statistics
using DataFrames
using Colors
using SIEParser

mytheme = Theme(
    Axis = (
        yminorgridvisible = true,
        yminorticks = IntervalsBetween(5)
    ),
    Figure = (
        figure_padding = 5,
    ),
#fontsize = 14,
linewidth = 0.7,
#backgroundcolor= :gray,
    
)
mythemeLatex = merge(mytheme, theme_latexfonts())
mythemeDarkLatex = merge(mythemeLatex, theme_dark())
set_theme!(mytheme)

CairoMakie.activate!(type = "svg");


include("markerExtractor.jl")
include("printCH.jl")
include("analysisTools.jl")
include("SIETidyr.jl")
include("plotTools.jl")
include("makeVertChartGen.jl")
include("canErr.jl")

export parseSIE
export makeChart
export markExtract
export CHInfo
export moving_mean
export sustained_max
export tidySIE
export canErrFindr

end
