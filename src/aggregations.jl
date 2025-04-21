
"""
    averages(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=0) where T

Returns a vector of N-1 time-weigted averages between the intervals of vt using either 
    (order=0) which uses the Riemann integral
    (order=1) which uses a trapezoidal integral
"""
function average(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=0) where T
    return aggregate(average, ts, vt; order=order)
end


"""
    integrate(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T

Returns a vector of N-1 integrals, bounded on the intervals of v with the following order options: 
    (order=0) which uses the Riemann integral
    (order=1) which uses a trapezoidal integral
"""
function integrate(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Union{Real,DateTime}}; order=0) where T
    return aggregate(integrate, ts, vt, order=order)
end

"""
    max(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}) where T

Returns a vector of N-1 maxima, bounded on the intervals of v with the following order options: 
"""
function Base.max(ts::TimeSeries, vt::AbstractVector{<:Real})
    return aggregate(max, ts, vt)
end

"""
    min(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}) where T

Returns a vector of N-1 minima, bounded on the intervals of v with the following order options: 
"""
function Base.min(ts::TimeSeries, vt::AbstractVector{<:Real})
    return aggregate(min, ts, vt)
end


"""
aggregate(f::Function, ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Union{Real,DateTime}}; order=0) where T <: Number

Aggregate a timeseries `ts` over intervals of `vt` using the aggregation function `f` with the following order options: 
    (order=0) which uses the Riemann integral
    (order=1) which uses a trapezoidal integral
"""
function aggregate(f::Function, ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Union{Real,DateTime}}; order=0) where T <: Number
    issorted(vt) || ArgumentError("Timestamps must be sorted")
    indhint = Ref(firstindex(ts))
    indfunc(ii::Integer) = f(ts, TimeInterval(vt[ii-1], vt[ii]), indhint=indhint, order=order)
    return map(indfunc, (firstindex(vt)+1):lastindex(vt))
end



"""
accumulate(ts::AbstractTimeSeries{T}; order=0) where T <: Number

Accumulate a timeseries over its time intervals, with the following order options: 
    (order=0) which uses the Riemann integral
    (order=1) which uses a trapezoidal integral
"""
function Base.accumulate(ts::AbstractTimeSeries{T}; order=0) where T
    ∫ts = fill(value(ts[begin])*0.0, length(ts)-1)

    for ii in firstindex(ts):(lastindex(ts)-1)
        ∫ti = ∫ts[max(ii-1, firstindex(ts))]
        ∫ts[ii] = ∫ti + integrate(ts[ii], ts[ii+1], order=order)
    end
    return ∫ts
end


"""
    integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval, indhint=firstindex(ts); order=0) where T <: Number

Integrate a timeseries over time interval Δt using either a trapezoid method (order=1) or a flat method (order=0)
"""
function integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing, order=0) where T
    if iszero(diff(Δt))
        return value(ts[begin])*0.0
        
    elseif Δt[end] < timestamp(ts[begin])
        @warn "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate"
        return value(ts[begin])*diff(Δt)

    elseif timestamp(ts[end]) < Δt[begin]
        if order > 0 #Completely after timesereis is not an issue for zero-order hold
            @warn "Time interval (Δt) occurs completely after the timeseries history, results are likely inaccurate"
        end
        return value(ts[end])*diff(Δt)
    end

    #Find the boundinh indices for the endpoints of Δt
    bnd1 = clampedbounds(ts, Δt[begin], indhint)
    bnd2 = clampedbounds(ts, Δt[end], bnd1[2])

    #Interpolate the end points Δt
    tsL = TimeRecord(Δt[begin], interpolate(ts[bnd1[begin]], ts[bnd1[end]], Δt[begin], order=order))
    tsU = TimeRecord(Δt[end], interpolate(ts[bnd2[begin]], ts[bnd2[end]], Δt[end], order=order))

    #Shortcut if Δt occurs completely within two timestamps
    if bnd1[end] > bnd2[begin]
        return integrate(tsL, tsU, order=order)
    end
    
    #Lay out the integral segment indices: inds[1] <= Δt[begin] <= inds[2] <= inds[3] <= Δt[end] <= inds[4]
    inds = (bnd1[begin], bnd1[end], bnd2[begin], bnd2[end])
    if !(inds[1] <= inds[2] <= inds[3] <= inds[4])
        error("Indices must be in ascending order")
    end
    _update_indhint!(indhint, inds[end])
    
    #Integrate the the first segment (obtained from interpolation)
    ∫ts = integrate(tsL, ts[inds[2]], order=order)

    #Integrate the middle segment if their indices are different
    if inds[2] < inds[3]
        ∫ts += integrate(view(ts, inds[2]:inds[3]), order=order)
    end

    #Integrate the final segment
    ∫ts += integrate(ts[inds[3]], tsU, order=order)

    return ∫ts
end

"""
    average(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing, order=0) where T <: Number

Integrate a timeseries over time interval Δt using either a trapezoid method (order=1) or a flat method (order=0)
Finally, divide integral by the elapsed time of Δt
"""
function average(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing, order=0) where T
    dt = diff(Δt)
    if iszero(dt) #Interval is zero, simply interpolate for the average (limit when dt -> 0)
        return interpolate(ts, Δt[begin], indhint=indhint, order=order)
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
        throw(ArgumentError("Time integrals are only supported for hold-last-value (order=0) and trapezoidal (order=1)"))
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

# ===================================================================================
# max/min aggregation methods which always use zeroth-order interpolation
# ===================================================================================
"""
    max(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing) where T <: Number

Return the maximum timeseries over time interval Δt starting with the immediate previous value
"""
function Base.max(ts::TimeSeries, Δt::TimeInterval; indhint=nothing, order=0)
    x0 = interpolate(ts, Δt[begin], indhint=indhint, order=0)
    return max(x0, maximum(value, view(ts, Δt), init=-Inf))
end

"""
    min(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing) where T <: Number

Return the maximum timeseries over time interval Δt starting with the immediate previous value
"""
function Base.min(ts::TimeSeries, Δt::TimeInterval; indhint=nothing, order=0)
    x0 = interpolate(ts, Δt[begin], indhint=indhint, order=0)
    return min(x0, minimum(value, view(ts, Δt), init=Inf))
end