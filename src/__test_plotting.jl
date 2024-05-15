using Revise
using Plots; pythonplot()
PythonPlot.pygui(true)

includet(joinpath(@__DIR__, "TimeRecords.jl"))
using .TimeRecords

N = 100

#Build random samples to simulate highly non-uniform data
vt0 = [0.0]
for ii in 2:N
    push!(vt0, vt0[ii-1] + 5.0*rand())
end
ts0 = TimeSeries(vt0, sin.(0.1.*vt0))

#Do time-averages for more evenly-sampled data
vt1 = LinRange(vt0[begin], vt0[end], N)
ts1 = time_averages(ts0, vt1, order=1)

#Resample via time-wegthted averages based off the following steps
# (1) Cumulatively integrating the TimeSeries in the original sample space
# (2) Interpolating the cumulative TimeSeries integral
# (3) Differencing the integral and dividing it by the time interval
#The "resampled" series should approximate "raw", it may lag a bit due to integration error
plot(datetime.(ts0), value.(ts0), label="raw")
plot!(datetime.(ts1), value.(ts1), label="resampled")