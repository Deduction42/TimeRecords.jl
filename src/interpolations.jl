include("find.jl")

#=======================================================================================================================
ToDo:
(4) Create "getindex" functions for timeseries that uses interpolation (by default) or extrapolation
     -  global settings should include: DEFAULT_ORDER, DEFAULT_INDEXER
=======================================================================================================================#
"""
interpolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)

Extrapolates timeseries ts::AbstractTimeSeries, at times vt::AbstractVector{Real}
Returns an ordinary TimeSeries with timestamps at vt
Keyword "order" selects algorithm: Supports zero-order-hold (order=0) and first-order-interpolation (order=1)
"""
function interpolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0, indhint=nothing)
    if order == 0
        return interpolate(_interpolate_lastval, ts, t, indhint=indhint)
    elseif order == 1
        return interpolate(_interpolate_linsat, ts, t, indhint=indhint)
    else
        throw(ArgumentError("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)"))
    end
end


"""
strictinterp(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)

Interpolates timeseries ts::AbstractTimeSeries, at times vt::AbstractVector{Real}
Returns an ordinary TimeSeries with timestamps at vt
Keyword "order" selects algorithm: Supports zero-order-hold (order=0) and first-order-interpolation (order=1)
"""
function strictinterp(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0, indhint=nothing)
    if order == 0
        return strictinterp(_interpolate_lastval, ts, t, indhint=indhint)
    elseif order == 1
        return strictinterp(_interpolate_linsat, ts, t, indhint=indhint)
    else
        throw(ArgumentError("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)"))
    end
end

"""
interpolate(r1::TimeRecord, r2::TimeRecord, t::Real; order=0)

Extrapolates from two time records (r1, r2) at point t using either zero-order hold (order=0) or saturated-linear (order=1)
"""
function interpolate(r1::TimeRecord, r2::TimeRecord, t::Real; order=0)
    if order == 0
        return _interpolate_lastval(r1, r2, t)
    elseif order == 1
        return _interpolate_linsat(r1, r2, t)
    else
        throw(ArgumentError("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)"))
    end
end

"""
Extrapolates a TimeSeries ts::AbstractTimeSeries at timestamps vt::AbstractVector{<:Real} using a two-point algorithm
Current two-point algorithms that are supported are zero-order-hold, first-order-interpolation
"""
function interpolate(f_extrap::Function, ts::AbstractTimeSeries, vt::AbstractVector{<:Real}; indhint=nothing)
    sortvt  = sort(vt)
    newhint = initialhint!(indhint, ts, first(sortvt))
    vals = map(t->interpolate(f_extrap, ts, t, indhint=newhint), sortvt)
    return TimeSeries(sortvt, vals)
end

"""
Interpolates a TimeSeries ts::AbstractTimeSeries at timestamps vt::AbstractVector{<:Real} using a two-point interpolation algorithm f_interp
Current two-point algorithms that are supported are zero-order-hold, first-order-interpolation
"""
function strictinterp(f_interp::Function, ts::AbstractTimeSeries, vt::AbstractVector{<:Real}; indhint=nothing)
    sortvt  = sort(vt)
    newhint = initialhint!(indhint, ts, first(sortvt)) 
    vals = map(t->strictinterp(f_interp, ts, t, indhint=newhint), sortvt)
    return TimeSeries(sortvt, vals)
end

"""
interpolate(f_interp::Function, ts::AbstractTimeSeries, t::Real, indhint::Union{Nothing,Integer,<:RefValue{<:Integer}})

Single extrapolation at time t::Real, provide an indhint for faster searching
"""
function interpolate(f_interp::Function, ts::AbstractTimeSeries, t::Real; indhint=nothing)
    (lb, ub) = clampedbounds(ts, t, indhint)
    return f_interp(ts[lb], ts[ub], t)
end

"""
strictinterp(f_interp::Function, ts::AbstractTimeSeries, t::Real, indhint::Union{Nothing,Integer,<:RefValue{<:Integer}})

Single interpolation at time t::Real, provide an indhint for faster searching
Will return TimeRecord{t, Missing} if t is not within the range of the timeseries
"""
function strictinterp(f_interp::Function, ts::AbstractTimeSeries, t::Real; indhint=nothing)
    (lb, ub) = findbounds(ts, t, indhint)
    if !(checkbounds(Bool, ts, lb) & checkbounds(Bool, ts, ub))
        return missing
    else
        return f_interp(ts[lb], ts[ub], t)
    end
end

# =================================================================================================
# Core two-point extrapolation algorithms
# =================================================================================================
function _interpolate_lastval(r1::TimeRecord, r2::TimeRecord, t::Real)
    usefirst = t < timestamp(r2)
    rt = ifelse(usefirst, r1, r2)
    return value(rt)
end

function _interpolate_linsat(r1::TimeRecord, r2::TimeRecord, t::Real)
    (w1, w2) = _linsat_weights(r1, r2, t)
    vt =  w1*value(r1) + w2*value(r2)
    return vt
end

function _linsat_weights(r1::TimeRecord, r2::TimeRecord, t::Real)
    t1 = timestamp(r1)
    t2 = timestamp(r2)
    Δt = t2-t1

    if iszero(Δt) #If the timestamps are identical so make the weights 50-50
        return (0.5, 0.5)
    end

    (w1, w2) = (t2-t, t-t1)./Δt
    return clamp.((w1, w2), 0, 1)
end


