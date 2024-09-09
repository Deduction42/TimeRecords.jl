"""
getinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer=firstindex(ts))

Return the elements of the Timeseries (ts) where Δt[begin] <= ts.t <= Δt[end]) 
"""
getinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=firstindex(ts))  = ts[findinner(ts, Δt, indhint)]
viewinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=firstindex(ts)) = @view ts[findinner(ts, Δt, indhint)]

"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint)

Return the elements of the Timeseries (ts) that surround the time interval Δt
"""
getouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=firstindex(ts))  = ts[findouter(ts, Δt, indhint)]
viewouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=firstindex(ts)) = @view ts[findouter(ts, Δt, indhint)]

"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer=firstindex(ts))

Finds the indices of the time series (ts) where Δt[begin] <= ts.t <= Δt[end]) 
"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer) = _unitrange(_innerbounds(ts, Δt, indhint))
findinner(ts::AbstractTimeSeries, Δt::TimeInterval) = findinner(ts, Δt, firstindex(ts))

"""
findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})

Finds the indices of the time series (ts) where Δt[begin] <= ts.t <= Δt[end]) 
Stores the last value of hte index range for future use
"""
function findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})
    (i0, i1) = _innerbounds(ts, Δt, indhint[])
    indhint[] = i1
    return i0:i1
end


"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint)

Finds the indices of the TimeSeries ts that surround the time interval Δt
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)
    (i0, i1) = _innerbounds(ts, Δt::TimeInterval, indhint)
    ongrid_lower = checkbounds(Bool, ts, i0) && Δt[begin] == timestamp(ts[i0])
    ongrid_upper = checkbounds(Bool, ts, i1) && timestamp(ts[i1]) == Δt[end]

    i0 = ifelse(ongrid_lower, i0, max(firstindex(ts), i0-1))
    i1 = ifelse(ongrid_upper, i1, min(lastindex(ts), i1+1))
    return i0:i1
end
findouter(ts::AbstractTimeSeries, Δt::TimeInterval) = findouter(ts, Δt, firstindex(ts))

"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})

Finds the indices of the TimeSeries ts that surround the time interval Δt and stores the value inside indhint for future use
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer}) 
    ind = findouter(ts, Δt, indhint[])
    indhint[] = ind[end]
    return ind
end


"""
_innerbounds(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)

Returns a pair of indices of a Timeseries (ts) such that Δt[begin] <= ts.t <= Δt[end]) 
"""
function _innerbounds(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)
    isinside(x::TimeRecord)  = Δt[begin] <= timestamp(x) <= Δt[end]
    isoutside(x::TimeRecord) = !isinside(x)

    ind0 = firstindex(ts)
    indN = lastindex(ts)
    indhint = clamp(indhint, ind0, indN)
    
    if timestamp(ts[indhint]) < Δt[begin] #Hint occurs before interval, walk forward to find it
        indL = something(findnext(isinside,  ts, indhint), indN+1)
        indH = something(findnext(isoutside, ts, indL), indN+1) - 1
        return indL=>indH

    elseif Δt[end] < timestamp(ts[indhint]) #Hint occurs after interval, walk backward to find it
        indH = something(findprev(isinside, ts, indhint), ind0-1)
        indL = something(findprev(isoutside, ts, indH), ind0-1) + 1
        return indL=>indH

    else #Hint occurs inside interval walk backward to find lower, and walk forward to find uppper
        indL = something(findprev(isoutside, ts, indhint), ind0-1) + 1
        indH = something(findnext(isoutside, ts, indhint), indN+1) - 1
        return indL=>indH
    end
end

_unitrange(x::Pair) = x[begin]:x[end]

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