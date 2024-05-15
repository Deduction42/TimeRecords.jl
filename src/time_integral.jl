"""
time_averages(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T

Time-weigted averages between the nodes of vt using either 
    (1) a trapezoid method (order=1) or (2) a flat method (order=0)
Timestamps in the resulting period refers to the END of the integral period, so the first element is always NaN
"""
function time_averages(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T
    ∫ts = interpolate(cumulative_integral(ts, order=order), vt, order=1)
    return TimeSeries(vt, [NaN; diff(values(∫ts))./diff(vt)])
end


"""
time_integrals(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T

Time integrals between the nodes of vt using either 
    (1) a trapezoid method (order=1) or (2) a flat method (order=0)
Timestamps in the resulting period refers to the END of the integral period, so the first element is always 0
"""
function time_integrals(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T
    ∫ts = interpolate(cumulative_integral(ts, order=order), vt, order=1)
    return TimeSeries(vt, [0; diff(values(∫ts))])
end

"""
cumulative_integral(ts::AbstractTimeSeries{T}; order=1) where T

Cumulative integral (as timeseries) over entire timeseries using either 
    (1) a trapezoid method (order=1) or (2) a flat method (order=0)
Timestamps in the resulting period refers to the END of the integral period, so the first element is always 0
    (this is done to prevent potential timeseries contamination with future information)
"""
function cumulative_integral(ts::AbstractTimeSeries{T}; order=1) where T
    #Calculate first integral to initialize the array
    ∫ts1 = time_integral(ts[begin], ts[begin+1], order=order)
    ∫ts  = zeros(typeof(∫ts1), length(ts))
    ∫ts[2] = ∫ts1

    i0 = firstindex(ts) - 1
    for ii in 3:length(∫ts)
        ∫ts[ii] = ∫ts[ii-1] + time_integral(ts[i0+ii-1], ts[i0+ii], order=order)
    end

    return TimeSeries(timestamp.(ts), ∫ts)
end


"""
time_integral(ts::AbstractTimeSeries{T}, Δt::TimeInterval; order=1) where T <: Number

Integrate a timeseries over time interval Δt using either a trapezoid method (order=1) or a flat method (order=0)
"""
function time_integral(ts::AbstractTimeSeries{T}, Δt::TimeInterval; order=1) where T <: Number
    if Δt[end] < timestamp(ts[begin])
        @warn "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate"
        return value(ts[begin])*diff(Δt)

    elseif timestamp(ts[end]) < Δt[begin]
        @warn "Time interval (Δt) occurs completely after the timeseries history, results are likely inaccurate"
        return value(ts[end])*diff(Δt)
    end

    b1 = SVector{2}(find_bounds(ts, Δt[begin], 1))
    bN = SVector{2}(find_bounds(ts, Δt[end], b1[end]))

    #Interpolate the outer boundaries and integrate them
    ts1  = interpolate(ts[b1], Δt[begin], order=order)
    tsN  = interpolate(ts[bN], Δt[end], order=order)

    #Obtain the initial integration for the two interpolated points
    ∫ts  = time_integral(ts1, ts[b1[end]], order=order)
    ∫ts += time_integral(ts[bN[begin]], tsN, order=order)

    #Integrate the inner segments
    for ii in b1[end]:(bN[begin]-1)
        ∫ts += time_integral(ts[ii], ts[ii+1])
    end

    return ∫ts
end


function time_integral(r1::TimeRecord{<:Real}, r2::TimeRecord{<:Real}; order=1)
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