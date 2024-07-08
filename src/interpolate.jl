#=======================================================================================================================
ToDo:
(1) findbounds should produce (Nothing, i₁) if query time is below range and (iₙ, Nothing) if above
     -  this will eliminate all the "something" logic for a higher-level function to handle
     -  clampbounds should replace Nothing with the other result
     -  clampbounds on a timeseries result applies clampbounds to a findbounds result
(2) Make interpolate produce "TimeRecord{t,missing}" if find_bounds has a Nothing
(3) Make a new extrapolate function that uses integer_bounds(find_bounds)
(4) Create "getindex" functions for timeseries that uses interpolation (by default) or extrapolation
     -  global settings should include: DEFAULT_ORDER, DEFAULT_INDEXER
(5) indhint should be a Ref{Int64} so that "two_point_interp" can be eliminated
     -  indhint=nothing should trigger a bisection search
=======================================================================================================================#
"""
extrapolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)

Extrapolates timeseries ts::AbstractTimeSeries, at times vt::AbstractVector{Real}
Returns an ordinary TimeSeries with timestamps at vt
Keyword "order" selects algorithm: Supports zero-order-hold (order=0) and first-order-interpolation (order=1)
"""
function extrapolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)
    if order == 0
        return extrapolate(extrapolate_lastval, ts, t)
    elseif order == 1
        return extrapolate(extrapolate_linsat, ts, t)
    else
        error("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)")
    end
end


"""
interpolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)

Interpolates timeseries ts::AbstractTimeSeries, at times vt::AbstractVector{Real}
Returns an ordinary TimeSeries with timestamps at vt
Keyword "order" selects algorithm: Supports zero-order-hold (order=0) and first-order-interpolation (order=1)
"""
function interpolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)
    if order == 0
        return interpolate(extrapolate_lastval, ts, t)
    elseif order == 1
        return interpolate(extrapolate_linsat, ts, t)
    else
        error("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)")
    end
end

"""
extrapolate(r1::TimeRecord, r2::TimeRecord, t::Real; order=0)

Extrapolates from two time records (r1, r2) at point t using either zero-order hold (order=0) or saturated-linear (order=1)
"""
function extrapolate(r1::TimeRecord, r2::TimeRecord, t::Real; order=0)
    if order == 0
        return extrapolate_lastval(r1, r2, t)
    elseif order == 1
        return extrapolate_linsat(r1, r2, t)
    else
        error("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)")
    end
end
extrapolate(rng::SVector{2,<:TimeRecord}, t::Real; order=0) = extrapolate(rng[1], rng[2], t, order=order)
extrapolate(rng::NTuple{2,<:TimeRecord}, t::Real; order=0)  = extrapolate(rng[1], rng[2], t, order=order)



"""
Extrapolates a TimeSeries ts::AbstractTimeSeries at timestamps vt::AbstractVector{<:Real} using a two-point algorithm
Current two-point algorithms that are supported are zero-order-hold, first-order-interpolation
"""
function extrapolate(f_extrap::Function, ts::AbstractTimeSeries, vt::AbstractVector{<:Real})
    indhint = Ref(1)    
    vtr = map(t->extrapolate(f_extrap, ts, t, indhint), sort(vt))
    return TimeSeries(vtr, issorted=true)
end

"""
Interpolates a TimeSeries ts::AbstractTimeSeries at timestamps vt::AbstractVector{<:Real} using a two-point interpolation algorithm f_interp
Current two-point algorithms that are supported are zero-order-hold, first-order-interpolation
"""
function interpolate(f_interp::Function, ts::AbstractTimeSeries, vt::AbstractVector{<:Real})
    indhint = Ref(1)    
    vtr = map(t->interpolate(f_interp, ts, t, indhint), sort(vt))
    return TimeSeries(vtr, issorted=true)
end

"""
extrapolate(f_interp::Function, ts::AbstractTimeSeries, t::Real, indhint::Union{Nothing,Integer,<:RefValue{<:Integer}})

Single extrapolation at time t::Real, provide an indhint for faster searching
"""
function extrapolate(f_extrap::Function, ts::AbstractTimeSeries, t::Real, indhint=nothing)
    (lb, ub) = clamp_bounds(ts, t, indhint)
    return f_extrap(ts[lb], ts[ub], t)
end

"""
interpolate(f_interp::Function, ts::AbstractTimeSeries, t::Real, indhint::Union{Nothing,Integer,<:RefValue{<:Integer}})

Single interpolation at time t::Real, provide an indhint for faster searching
Will return TimeRecord{t, Missing} if t is not within the range of the timeseries
"""
function interpolate(f_extrap::Function, ts::AbstractTimeSeries, t::Real, indhint=nothing)
    (lb, ub) = find_bounds(ts, t, indhint)
    if isnothing(lb) | isnothing(ub)
        return TimeRecord(t, missing)
    else
        return f_extrap(ts[lb], ts[ub], t)
    end
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
        

    

# =================================================================================================
# Core two-point extrapolation algorithms
# =================================================================================================
function extrapolate_lastval(r1::TimeRecord, r2::TimeRecord, t::Real)
    usefirst = t < timestamp(r2)
    rt = ifelse(usefirst, r1, r2)
    return TimeRecord(t, value(rt))
end

function extrapolate_linsat(r1::TimeRecord, r2::TimeRecord, t::Real)
    rng = (r1, r2)
    rt = timestamp.(rng)
    rv = value.(rng)
    Δt = timestamp(rng[2]) - timestamp(rng[1])
    
    if iszero(Δt) #If times are identical just produce average
        return TimeRecord(t, 0.5*sum(rv))
    end

    w_raw = (rt[2]-t, t-rt[1]) ./ Δt  #weights based on proximity of t to the record
    w_clamped = clamp.(w_raw, 0, 1)   #Clamp the weights so it doesn't extrapolate if r is outside
    return TimeRecord(t, sum(rv .* w_clamped)) 
end


