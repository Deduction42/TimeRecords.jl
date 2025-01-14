include("_TimeSeries.jl")

"""
getinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer=firstindex(ts))

Return the elements of the Timeseries (ts) where Δt[begin] <= ts.t <= Δt[end]) 
"""
getinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing)  = ts[findinner(ts, Δt, indhint)]
viewinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing) = @view ts[findinner(ts, Δt, indhint)]

"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint)

Return the elements of the Timeseries (ts) that surround the time interval Δt
"""
getouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing)  = ts[findouter(ts, Δt, indhint)]
viewouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing) = @view ts[findouter(ts, Δt, indhint)]



"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer=firstindex(ts))

Finds the indices of the time series (ts) where Δt[begin] <= ts.t <= Δt[end]) 
"""
function findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing)
    if isempty(ts)
        return 1:0
    end
    
    lb = findbounds(ts, Δt[begin], indhint)[2]
    ub = findbounds(ts, Δt[end], lb)[1]
    return lb:ub
end

"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})

Finds the indices of the time series (ts) where Δt[begin] <= ts.t <= Δt[end]) 
Stores the last value of hte index range for future use
"""
function findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})
    ind = findinner(ts, Δt, indhint[])
    indhint[] = ind[end]
    return ind
end


"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint)

Finds the indices of the TimeSeries ts that surround the time interval Δt, 
If Δt is outside the time range both results will be the nearest index
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing)
    if isempty(ts)
        return 1:0
    end

    lb = clampedbounds(ts, Δt[begin], indhint)[1]
    ub = clampedbounds(ts, Δt[end], lb)[2]
    return lb:ub
end

"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})

Finds the indices of the TimeSeries ts that surround the time interval Δt and stores the value inside indhint for future use
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer}) 
    ind = findouter(ts, Δt, indhint[])
    indhint[] = ind[end]
    return ind
end

_unitrange(x::Pair) = x[begin]:x[end]

"""
findbounds(ts::AbstractTimeSeries, t::Real, indhint::Integer)

Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
If t is not inside the timeseries, one of the bounds will not be in its index range
If in-range bounds are desired, use clampedbounds(ts, t, indhint) instead
"""
function findbounds(ts::AbstractTimeSeries, t::Real, indhint::Integer)
    earlier_than_t(x::TimeRecord) = timestamp(x) <= t
    later_than_t(x::TimeRecord)   = timestamp(x) >= t

    (ind0, indN) = (firstindex(ts), lastindex(ts))
    indhint = clamp(indhint, ind0, indN)

    if earlier_than_t(ts[indhint]) #Walk forward in time if indhint record occurs earlier than t
        ub = findnext(later_than_t, ts, indhint)
        if isnothing(ub)
            return indN => (indN+1)
        else
            return _bounds_from_upper(ub, ts, t)
        end
        
    else #Walk backwards in time if indhint reccord occurs later than t
        lb = findprev(earlier_than_t, ts, indhint)
        if isnothing(lb)
            return (ind0-1) => ind0
        else
            return _bounds_from_lower(lb, ts, t)
        end
    end
end

"""
findbounds(ts::AbstractTimeSeries, t::Real, indhint::Base.RefValue{<:Integer})

Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
Previous results are saved in indhint in order to provide hits for future calls if they're made in order
If t is not inside the timeseries, one of the bounds will not be in its index range
If in-range bounds are desired, use clampedbounds(ts, t, indhint) instead
"""
function findbounds(ts::AbstractTimeSeries, t::Real, indhint::Base.RefValue{<:Integer})
    (lb, ub) = findbounds(ts, t, indhint[])
    indhint[] = clamp(ub, firstindex(ts), lastindex(ts))
    return lb => ub
end


"""
findbounds(ts::AbstractTimeSeries, t::Real)

Finds the index of the TimeRecord before and after t::Real using the bisection method
If t is not inside the timeseries, one of the bounds will not be in its index range
If in-range bounds are desired, use clampedbounds(ts, t, indhint) instead
"""
function findbounds(ts::AbstractTimeSeries, t::Real)
    (lb, ub) = (firstindex(ts), lastindex(ts))
    T = typeof(lb)

    if t < timestamp(ts[lb])
        return (lb-1)=>lb
    elseif timestamp(ts[ub]) < t
        return ub => (ub+1)
    end

    while (ub-lb) > 1
        mb = ceil(T, 0.5*(lb+ub))
        if timestamp(ts[mb]) < t
            (lb, ub) = (mb, ub)
        else
            (lb, ub) = (lb, mb)
        end
    end

    return _narrow_bounds(lb=>ub, ts, t)
end

findbounds(ts::AbstractTimeSeries, t::Real, indhint::Nothing) = findbounds(ts, t)

"""
initialhint(ts::AbstractTimeSeries, t::Real)

Produces a RefValue with the last index of ts that is less than or equal to t (uses bisection method)
"""
function initialhint(ts::AbstractTimeSeries, t::Real)
    (lb, ub)  = findbounds(ts, t)
    return Base.RefValue(clampindex(lb,ts))
end


"""
initialhint!(indhint::Base.RefValue, ts::AbstractTimeSeries, t::Real)

Initializes a RefValue with the last index of ts that is less than or equal to t (uses bisection method)
"""
function initialhint!(indhint::Base.RefValue, ts::AbstractTimeSeries, t::Real)
    (lb, ub)  = findbounds(ts, t)
    indhint[] = clampindex(lb, ts)
    return indhint
end

initialhint!(indhint::Nothing, ts::AbstractTimeSeries, t::Real) = initialhint(ts, t)
initialhint!(indhint::Integer, ts::AbstractTimeSeries, t::Real) = initialhint(ts, t)

"""
clampedbounds(ts::AbstractTimeSeries, t::Real, indhint=nothing)

Behaves like findbounds except that it always returns integer boundaries within the timeseries bounds
Out-of-bound results yield repeating lower bounds, or repeating upper bounds
"""
function clampedbounds(ts::AbstractTimeSeries, t::Real, indhint=nothing) 
    (lb, ub) = findbounds(ts, t, indhint)
    (minb, maxb) = (firstindex(ts), lastindex(ts))
    return clamp(lb, minb, maxb) => clamp(ub, minb, maxb)
end

"""
clampindex(ind::Integer, ts::AbstractTimeSeries)

Clamps ind so that it is always within the bounds of ts
"""
function clampindex(ind::Integer, ts::AbstractTimeSeries)
    return clamp(ind, firstindex(ts), lastindex(ts))
end

#============================================================================================
Indhint handling for ref values
============================================================================================#
function _update_indhint!(indhint::Base.Ref, v::Integer)
    indhint[] = v
    return indhint
end

_update_indhint!(indhint, v::Integer) = v


#============================================================================================
Create boundary pair from lower and upper bounds
This will duplicate the boundary if its timestamp lines up closely with t
============================================================================================#
function _bounds_from_lower(lb::Integer, ts::AbstractTimeSeries, t::Real)
    return ifelse(timestamp(ts[lb])==t, lb=>lb, lb=>(lb+1))
end

function _bounds_from_upper(ub::Integer, ts::AbstractTimeSeries, t::Real)
    return ifelse(timestamp(ts[ub])==t, ub=>ub, (ub-1)=>ub)
end

function _narrow_bounds(bnd::Pair{<:Integer,<:Integer}, ts::AbstractTimeSeries, t::Real)
    (lb, ub) = bnd
    lb = ifelse(timestamp(ts[ub])==t, ub, lb)
    ub = ifelse(timestamp(ts[lb])==t, lb, ub)
    return lb=>ub
end