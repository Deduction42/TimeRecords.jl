"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)

Finds the indices of the time series (ts) surrounding the time interval (Δt) or nearest (if Δt extends beyond (ts)) 
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)
    
    after_begin_excl(x::TimeRecord)  = Δt[begin] < timestamp(x)
    after_end_incl(x::TimeRecord)    = Δt[end] <= timestamp(x)
    before_end_excl(x::TimeRecord)   = timestamp(x) < Δt[end]
    before_begin_incl(x::TimeRecord) = timestamp(x) <= Δt[begin]

    ind0 = firstindex(ts)
    indN = lastindex(ts)
    indhint = clamp(indhint, ind0, indN)
    
    if timestamp(ts[indhint]) < Δt[begin] #Hint occurs before interval, walk forward to find it
        indL = something(findnext(after_begin_excl, ts, indhint), indN+1) - 1
        indH = something(findnext(after_end_incl, ts, indL), indN)
        return indL:indH

    elseif Δt[end] < timestamp(ts[indhint]) #Hint occurs after interval, walk backward to find it
        indH = something(findprev(before_end_excl, ts, indhint), ind0-1) + 1
        indL = something(findprev(before_begin_incl, ts, indH), ind0)
        return indL:indH

    else #Hint occurs inside interval walk backward to find lower, and walk forward to find uppper
        indL = something(findprev(before_begin_incl, ts, indhint), ind0)
        indH = something(findnext(after_end_incl, ts, indhint), indN)
        return indL:indH
    end
end

findouter(ts::AbstractTimeSeries, Δt::TimeInterval) = findouter(ts, Δt, firstindex(ts))

"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})

Finds the indices of the time series (ts) surrounding the time interval (Δt) or nearest (if Δt extends beyond (ts)) 
Stores upper limit of result inside indhint for future reference
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})
    inds = findouter(ts, Δt, indhint[])
    if length(inds) > 0
        indhint[] = inds[end]
    end
    return inds
end

"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint)

Finds the indices of the TimeSeries inside the time interval Δt::TimeInterval
Stores upper limit of result inside indhint for future reference if indhint is a RefValue
"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint) = _findinner(findouter(ts, Δt, indhint))
findinner(ts::AbstractTimeSeries, Δt::TimeInterval) = findinner(ts, Δt, firstindex(ts))

_findinner(outer::UnitRange) = (outer[begin]+1):(outer[end]-1)



"""
findbounds(ts::AbstractTimeSeries, t::Real, indhint::Integer)

Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
"""
function findbounds(ts::AbstractTimeSeries, t::Real, indhint::Integer)
    earlier_than_t(x::TimeRecord) = timestamp(x) <= t
    later_than_t(x::TimeRecord)   = timestamp(x) >= t

    ind0 = firstindex(ts)
    indN = lastindex(ts)
    indhint = clamp(indhint, ind0, indN)

    if earlier_than_t(ts[indhint]) #Walk forward in time if indhint record occurs earlier than t
        indH = findnext(later_than_t, ts, indhint)
        indL = something(indH, indN+1) - 1
        indL = max(indL, ind0)
        return (indL, indH)
        
    else #Walk backwards in time if indhint reccord occurs later than t
        indL = findprev(earlier_than_t, ts, indhint)
        indH = something(indL, firstindex(ts)-1) + 1
        indH = min(indH, indN)
        return (indL, indH)
    end
end

"""
findbounds(ts::AbstractTimeSeries, t::Real, indhint::RefValue{<:Integer})

Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
The upper limit of the boundary is saved in indhint (unless it's nothing, then the lower boundary is saved)
"""
function findbounds(ts::AbstractTimeSeries, t::Real, indhint::Base.RefValue{<:Integer})
    (lb, ub) = findbounds(ts, t, indhint[])
    indhint[] = something(ub, lb)
    return (lb, ub)
end


"""
findbounds(ts::AbstractTimeSeries, t::Real)

Finds bounding indices for timeseries (ts) at time (t) using a bisection method
"""
function findbounds(ts::AbstractTimeSeries, t::Real)
    (lb, ub) = (firstindex(ts), lastindex(ts))

    if t < timestamp(ts[lb])
        return (nothing, lb)
    elseif timestamp(ts[ub]) < t
        return (ub, nothing)
    end

    while (ub-lb) > 1
        mb = ceil(Int64, 0.5*(lb+ub))
        if timestamp(ts[mb]) < t
            (lb, ub) = (mb, ub)
        else
            (lb, ub) = (lb, mb)
        end
    end

    return (lb, ub)
end

findbounds(ts::AbstractTimeSeries, t::Real, indhint::Nothing) = findbounds(ts, t)

"""
findnearest(ts::AbstractTimeSeries, t::Real, indhint::RefValue{<:Integer})

Behaves like findbounds except that it always returns integer boundaries within the timeseries bounds
"""
findnearest(ts::AbstractTimeSeries, t::Real, indhint) = clampbounds(findbounds(ts, t, indhint))

"""
findnearest(Tuple{Union{Integer,Nothing}, Union{Integer,Nothing}})

Clamps the result of findbounds so that Nothing is not inside the results
"""
clampbounds(t::Tuple{Nothing, <:Integer})   = (t[2],t[2])
clampbounds(t::Tuple{<:Integer, Nothing})   = (t[1],t[1])
clampbounds(t::Tuple{<:Integer, <:Integer}) = t