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
linewidth = 1,
#backgroundcolor= :gray,
    
)
mythemeLatex = merge(mytheme, theme_latexfonts())
mythemeDarkLatex = merge(mythemeLatex, theme_dark())
set_theme!(mytheme)

CairoMakie.activate!(type = "svg");

include("makeVertChartGen.jl")
include("markerExtractor.jl")
include("printCH.jl")
#include("parseSIEKerchoo.jl")

export parseSIE
export makeChart
export markExtract
export CHInfo
# Write your package code here.

end
