#=======================================================================================================================
ToDo:
(0) Create TimeSeriesView to represent views of timeseries
     -  findinner(ts, Δt, indhint) should return indices where Δt[begin] <= t <= Δt[end]
     -  innerview(ts, Δt, indhint) should return a view of the timestamps between Δt[begin], Δt[end]
     -  outerview(ts, Δt, indhint) should return a view of the timestamps that are just outside Δt[begin], Δt[end]
(1) time_integral should have a basic function for AbstractTimeSeries (no bounds) like what we use for cumulative_integral
(2) When time ranges are applied, find the inner view, integrate, and add the integrals of the extrapolated end values
(3) time_average just divides the integral by the time difference
(4) time_integral(...) and time_average(...) should allow passing indhint
     -  time_integrals(...) and time_averages(...) should pass indhint
=======================================================================================================================#

"""
averages(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=0) where T

Time-weigted averages between the nodes of vt using either 
    (1) a trapezoid method (order=1) or (2) a flat method (order=0)
Timestamps in the resulting period refers to the END of the integral period, so the first element is always NaN
"""
function average(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=0) where T
    ∫ts = integrate(ts, vt, order=order)
    return TimeSeries(vt[(begin+1):end], value.(∫ts)./diff(vt))
end


"""
integrate(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T

Return a Timeseries of N-1 integrals, bounded on the intervals of v with the following order options: 
    (order=0) which uses the Riemann integral
    (order=1) which uses a trapezoidal integral
Timestamps in the resulting period refers to the END of each interval
"""
function integrate(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Union{Real,DateTime}}; order=0) where T
    indhint = Ref(firstindex(ts))
    ∫ts = zeros(promote_type(T, Float64), length(vt)-1)

    for ii in firstindex(vt):(lastindex(vt)-1)
        Δt = TimeInterval(vt[ii], vt[ii+1])
        ∫ts[ii] = integrate(ts, Δt, indhint, order=order)
    end
    return TimeSeries(vt[(begin+1):end], ∫ts)
end


"""
accumulate(ts::AbstractTimeSeries{T}; order=0) where T <: Number

Accumulate a timeseries over its time intervals, with the following order options: 
    (order=0) which uses the Riemann integral
    (order=1) which uses a trapezoidal integral
This produces a new timeseries with N-1 entries stamped at the end of each interval
"""
function Base.accumulate(ts::AbstractTimeSeries{T}; order=0) where T
    ∫ts = zeros(promote_type(T, Float64), length(ts)-1)

    for ii in firstindex(ts):(lastindex(ts)-1)
        ∫ti = ∫ts[max(ii-1, firstindex(ts))]
        ∫ts[ii] = ∫ti + integrate(ts[ii], ts[ii+1], order=order)
    end
    return TimeSeries(timestamp.(ts[(begin+1):end]), ∫ts)
end


"""
integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval, indhint=firstindex(ts); order=0) where T <: Number

Integrate a timeseries over time interval Δt using either a trapezoid method (order=1) or a flat method (order=0)
"""
function integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval, indhint=firstindex(ts); order=0) where T <: Number
    if iszero(diff(Δt))
        return zero(promote_type(T, Float64))
        
    elseif Δt[end] < timestamp(ts[begin])
        @warn "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate"
        return value(ts[begin])*diff(Δt)

    elseif timestamp(ts[end]) < Δt[begin]
        @warn "Time interval (Δt) occurs completely after the timeseries history, results are likely inaccurate"
        return value(ts[end])*diff(Δt)
    end

    #Find the indices in "ts" that bound Δt
    ind  = findouter(ts, Δt, indhint)
    (ia, ib, ic, id) = (ind[begin], ind[begin+1], ind[end-1], ind[end])
    
    #interpolate from the boundaries
    ts1  = interpolate(ts[ia], ts[ib], Δt[begin], order=order)
    tsN  = interpolate(ts[ic], ts[id], Δt[end], order=order)

    #Integrate the initial segment
    ∫ts  = integrate(ts1, ts[ib], order=order)
    
    #Integrate the inner segments
    ∫ts += integrate(view(ts, ib:ic), order=order)

    #Integrate the final segments
    ∫ts += integrate(ts[ic], tsN, order=order)

    return ∫ts
end


"""
integrate(ts::AbstractTimeSeries{T}; order=0) where T <: Number

Integrate a timeseries using either a trapezoid method (order=1) or a flat method (order=0)
"""
function integrate(ts::AbstractTimeSeries{T}; order=0) where T <: Number
    ∫ts = zero(promote_type(T, Float64))
    for ii in firstindex(ts):(lastindex(ts)-1)
        ∫ts += integrate(ts[ii], ts[ii+1], order=order)
    end
    return ∫ts
end

function integrate(r1::TimeRecord{<:Real}, r2::TimeRecord{<:Real}; order=0)
    if order == 1
        return trapezoid_integral(r1, r2)
    elseif order ==0
        return lastval_integral(r1, r2)
    else
        error("Time integrals are only supported for hold-last-value (order=0) and trapezoidal (order=1)")
    end
end

# ===================================================================================
# Core integration methods
# ===================================================================================
function lastval_integral(r1::TimeRecord{<:Real}, r2::TimeRecord{<:Real})
    return value(r1)*diff(TimeInterval(r1, r2))
end

function trapezoid_integral(r1::TimeRecord{<:Real}, r2::TimeRecord{<:Real})
    μ = 0.5*(value(r1) + value(r2))
    return μ*diff(TimeInterval(r1, r2))
end