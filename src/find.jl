"""
find_inner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)

Finds the indices of the TimeSeries inside the time interval Δt::TimeInterval
"""
function find_inner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)
    inside_interval(x::TimeRecord)  = Δt[begin] <= timestamp(x) <= Δt[end]
    outside_interval(x::TimeRecord) = !inside_interval(x)

    ind0 = firstindex(ts)
    indN = lastindex(ts)
    indhint = clamp(indhint, ind0, indN)
    
    if timestamp(ts[indhint]) < Δt[begin] #Hint occurs before interval, walk forward to find it
        indL = something(findnext(inside_interval, ts, indhint), indN+1)
        indH = something(findnext(outside_interval, ts, indL), indN+1) - 1
        return indL:indH

    elseif Δt[end] < timestamp(ts[indhint]) #Hint occurs after interval, walk backward to find it
        indH = something(findprev(inside_interval, ts, indhint), ind0-1)
        indL = something(findprev(outside_interval, ts, indH), ind0-1) + 1
        return indL:indH

    else #Hint occurs inside interval walk backward to find lower, and walk forward to find uppper
        indL = something(findprev(outside_interval, ts, indhint), ind0-1) + 1
        indH = something(findnext(outside_interval, ts, indL), indN+1) - 1
        return indL:indH
    end
end

find_inner(ts::AbstractTimeSeries, Δt::TimeInterval) = find_inner(ts, Δt, firstindex(ts))

"""
find_inner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Integer)

Finds the indices of the TimeSeries inside the time interval Δt::TimeInterval, 
Stores upper limit of result inside indhint for future reference
"""
function find_inner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint::Base.RefValue{<:Integer})
    inds = find_inner(ts, Δt, indhint[])
    if length(inds) > 0
        indhint[] = inds[end]
    end
    return inds
end


"""
find_bounds(ts::AbstractTimeSeries, t::Real, indhint::Integer)

Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
"""
function find_bounds(ts::AbstractTimeSeries, t::Real, indhint::Integer)
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
find_bounds(ts::AbstractTimeSeries, t::Real, indhint::RefValue{<:Integer})

Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
The upper limit of the boundary is saved in indhint (unless it's nothing, then the lower boundary is saved)
"""
function find_bounds(ts::AbstractTimeSeries, t::Real, indhint::Base.RefValue{<:Integer})
    (lb, ub) = find_bounds(ts, t, indhint[])
    indhint[] = something(ub, lb)
    return (lb, ub)
end


"""
find_bounds(ts::AbstractTimeSeries, t::Real)

Finds bounding indices for timeseries (ts) at time (t) using a bisection method
"""
function find_bounds(ts::AbstractTimeSeries, t::Real)
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

find_bounds(ts::AbstractTimeSeries, t::Real, indhint::Nothing) = find_bounds(ts, t)

"""
clamp_bounds(ts::AbstractTimeSeries, t::Real, indhint::RefValue{<:Integer})

Behaves like find_bounds except that it always returns integer boundaries within the timeseries bounds
"""
clamp_bounds(ts::AbstractTimeSeries, t::Real, indhint) = clamp_bounds(find_bounds(ts, t, indhint))

"""
clamp_bounds(Tuple{Union{Integer,Nothing}, Union{Integer,Nothing}})

Clamps the result of find_bounds so that Nothing is not inside the results
"""
clamp_bounds(t::Tuple{Nothing, <:Integer})   = (t[2],t[2])
clamp_bounds(t::Tuple{<:Integer, Nothing})   = (t[1],t[1])
clamp_bounds(t::Tuple{<:Integer, <:Integer}) = t