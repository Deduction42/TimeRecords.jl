using Revise
using Plots
using TimeRecords
using Dates

#Test problematic case where timestamps are close together but span a date 
vt = DateTime(2026,01,01,23):Minute(1):DateTime(2026,01,02,2)
vx = 0.1.*(1:length(vt))
plot(TimeSeries(vt, vx))

#Test case where timestamps are close together and in the same date 
plot(TimeSeries(vt.- Hour(4), vx))

#=
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
=#