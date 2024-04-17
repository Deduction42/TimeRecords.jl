using StaticArrays
using Dates

include(joinpath(@__DIR__, "_TimeRecord.jl"))
include(joinpath(@__DIR__, "_TimeSeries.jl"))
include(joinpath(@__DIR__, "interpolate.jl"))
include(joinpath(@__DIR__, "time_integral.jl"))
include(joinpath(@__DIR__, "tabular_form.jl"))

#Testing time integrals
#ts = TimeSeries(0:5, 0:5)
#Δt = TimeInterval(-2,-1); result = time_integral(ts, Δt, order=1)