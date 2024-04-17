"""
Cumulative integral over entire timeseries using either a trapezoid method (order=1) or a flat method (order=0)
"""
function time_integral(ts::AbstractTimeSeries{T}; order=1) where T
    ∫ts = time_integral(ts[begin], ts[begin+1], order=order)

    for ii in (firstindex(ts)+1):(lastindex(ts)-1)
        ∫ts += time_integral(ts[ii], ts[ii+1], order=order)
    end
    return ∫ts
end


"""
Integrate a timeseries over time interval using either a trapezoid method (order=1) or a flat method (order=0)
"""
function time_integral(ts::AbstractTimeSeries{T}, Δt::TimeInterval; order=1) where T <: Number
    if Δt[end] < timestamp(ts[begin])
        @warn "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate"
        return record(ts[begin])*diff(Δt)

    elseif timestamp(ts[end]) < Δt[begin]
        @warn "Time interval (Δt) occurs completely after the timeseries history, results are likely inaccurate"
        return record(ts[end])*diff(Δt)
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
    return record(r1)*diff(TimeInterval(r1, r2))
end

function trapezoid_integral(r1::TimeRecord{<:Real}, r2::TimeRecord{<:Real})
    μ = 0.5*(record(r1) + record(r2))
    return μ*diff(TimeInterval(r1, r2))
end