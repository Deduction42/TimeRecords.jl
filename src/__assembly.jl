using StaticArrays
using Dates

include(joinpath(@__DIR__, "_TimeSeriesCollector.jl"))

#Testing time integrals
#ts = TimeSeries(0:5, 0:5)
#Δt = TimeInterval(-2,-1); result = time_integral(ts, Δt, order=1)