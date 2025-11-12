module SIETools

using CairoMakie
using StatsKit
using Colors
using EzXML

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
include("parseSIEKerchoo.jl")

export parseSIE
export makeChart
export markExtract
# Write your package code here.

end
