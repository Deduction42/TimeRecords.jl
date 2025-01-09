include("interpolate.jl")


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
    ∫ts = fill(value(ts[begin])*0.0, length(vt)-1)

    for ii in firstindex(vt):(lastindex(vt)-1)
        Δt = TimeInterval(vt[ii], vt[ii+1])
        ∫ts[ii] = integrate(ts, Δt, indhint=indhint, order=order)
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
    ∫ts = fill(value(ts[begin])*0.0, length(ts)-1)

    for ii in firstindex(ts):(lastindex(ts)-1)
        ∫ti = ∫ts[max(ii-1, firstindex(ts))]
        ∫ts[ii] = ∫ti + integrate(ts[ii], ts[ii+1], order=order)
    end
    return TimeSeries(timestamp.(ts[(begin+1):end]), ∫ts)
end


"""
integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval, indhint=firstindex(ts); order=0) where T <: Number

Integrate a timeseries over time interval Δt using either a trapezoid method (order=1) or a flat method (order=0)

Performance recommendations:
 -  If this function is used only once on this timeseries, set indhint=nothing to use a bisection search
 -  If this function is used multiple times on the same timeseries in order, set indhint=initialize!(Ref(1), ts, Δt[begin])
"""
function integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing, order=0) where T
    if iszero(diff(Δt))
        return value(ts[begin])*0.0
        
    elseif Δt[end] < timestamp(ts[begin])
        @warn "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate"
        return value(ts[begin])*diff(Δt)

    elseif timestamp(ts[end]) < Δt[begin]
        @warn "Time interval (Δt) occurs completely after the timeseries history, results are likely inaccurate"
        return value(ts[end])*diff(Δt)
    end

    #Find the integral segment indices: segs[1] <= Δt[begin] <= segs[2] <= segs[3] <= Δt[end] <= segs[4]
    bnd1 = clampedbounds(ts, Δt[begin], indhint)
    bnd2 = clampedbounds(ts, Δt[end], bnd1[2])
    inds = (bnd1[begin], bnd1[end], bnd2[begin], bnd2[end])

    _update_indhint!(indhint, inds[end])

    #Initialize the integral
    ∫ts  = zero(promote_type(T, Float64))
    
    #If Δt[begin] doesn't line up withe first segment, use interpolation and add to integral
    if timestamp(ts[inds[2]]) != Δt[begin]
        tsL = interpolate(ts[inds[1]], ts[inds[2]], Δt[begin], order=order)
        ∫ts += integrate(tsL, ts[inds[2]], order=order)
    end

    #If segs[2] and segs[3] are different, there is data between them so we can integrate in that region
    if inds[2] != inds[3]
        ∫ts += integrate(view(ts, inds[2]:inds[3]), order=order)
    end

    #If Δt[end] doesn't line up withe final segment, use interpolation and add to integral
    if timestamp(ts[inds[3]]) != Δt[end]
        tsU = interpolate(ts[inds[3]], ts[inds[4]], Δt[end], order=order)
        ∫ts += integrate(ts[inds[3]], tsU, order=order)
    end    

    return ∫ts
end

"""
average(ts::AbstractTimeSeries{T}, Δt::TimeInterval, indhint=firstindex(ts); order=0) where T <: Number

Integrate a timeseries over time interval Δt using either a trapezoid method (order=1) or a flat method (order=0)
Finally, divide integral by the elapsed time of Δt

Performance recommendations:
 -  If this function is used only once on this timeseries, set indhint=nothing to use a bisection search
 -  If this function is used multiple times on the same timeseries in order, set indhint=initialize!(Ref(1), ts, Δt[begin])
"""
function average(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing, order=0) where T
    dt = diff(Δt)
    if iszero(dt) #Interval is zero, simply interpolate for the average (limit when dt=>0)
        return interpolate(ts, Δt[begin], order=order)
    else
        return integrate(ts, Δt, indhint=indhint, order=order)/dt
    end
end

"""
integrate(ts::AbstractTimeSeries{T}; order=0) where T

Integrate a timeseries using either a trapezoid method (order=1) or a flat method (order=0)
"""
function integrate(ts::AbstractTimeSeries{T}; order=0) where T
    if isempty(ts)
        return zero(T)*0.0
    end

    ∫ts = value(ts[begin])*0.0
    for ii in firstindex(ts):(lastindex(ts)-1)
        ∫ts += integrate(ts[ii], ts[ii+1], order=order)
    end
    return ∫ts
end

function integrate(r1::TimeRecord, r2::TimeRecord; order=0)
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
function lastval_integral(r1::TimeRecord, r2::TimeRecord)
    return value(r1)*diff(TimeInterval(r1, r2))
end

function trapezoid_integral(r1::TimeRecord, r2::TimeRecord)
    μ = 0.5*(value(r1) + value(r2))
    return μ*diff(TimeInterval(r1, r2))
end