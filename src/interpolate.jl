#=======================================================================================================================
ToDo:
(1) find_bounds should produce (Nothing, i₁) if query time is below range and (iₙ, Nothing) if above
     -  inner_bounds should replace Nothing with the other result
(2) Make interpolate produce "TimeRecord{t,missing}" if find_bounds has a Nothing
(3) Make a new extrapolate function that uses integer_bounds(find_bounds)
(4) Create "getindex" functions for timeseries that uses interpolation (by default) or extrapolation
     -  global settings should include: DEFAULT_ORDER, DEFAULT_INDEXER
=======================================================================================================================#


"""
interpolate(ts::AbstractTimeSeries, vt::AbstractVector{<:Real}; order=0)

Interpolates timeseries ts::AbstractTimeSeries, at times vt::AbstractVector{Real}
Returns an ordinary TimeSeries with timestamps at vt
Keyword "order" selects algorithm: Supports zero-order-hold (order=0) and first-order-interpolation (order=1)
"""
function interpolate(ts::AbstractTimeSeries, vt::AbstractVector{<:Real}; order=0)
    if order == 0
        return interpolate(interp_lastval, ts, vt)
    elseif order == 1
        return interpolate(interp_linear, ts, vt)
    else
        error("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)")
    end
end


interpolate(rng::SVector{2,<:TimeRecord}, t::Real; order=0) = interpolate(rng[1], rng[2], t, order=order)
interpolate(rng::NTuple{2,<:TimeRecord}, t::Real; order=0)  = interpolate(rng[1], rng[2], t, order=order)

"""
interpolate(r1::TimeRecord, r2::TimeRecord, t::Real; order=0)

Interpolates between two time records (r1, r2) at point t
"""
function interpolate(r1::TimeRecord, r2::TimeRecord, t::Real; order=0)
    if order == 0
        return interp_lastval(r1, r2, t)
    elseif order == 1
        return interp_linear(r1, r2, t)
    else
        error("Keyword 'order' only supports zero-order-hold (order=0) and first-order-interpolation (order=1)")
    end
end

"""
Interpolates a TimeSeries ts::AbstractTimeSeries at timestamps vt::AbstractVector{<:Real} using a two-point interpolation algorithm f_interp
Current two-point algorithms that are supported are zero-order-hold, first-order-interpolation
"""
function interpolate(f_interp::Function, ts::AbstractTimeSeries, vt::AbstractVector{<:Real})
    indhint = Ref(1)

    function interp_for_time(t::Real)
        itp = two_point_interp(f_interp, ts, t, indhint=indhint[])
        indhint[] = itp.indhint
        return itp.result
    end
    
    vtr = [interp_for_time(t) for t in sort(vt)]
    return TimeSeries(vtr, issorted=true)
end

"""
Single interpolation at time t::Real, provide an indhint for faster searching
"""
function two_point_interp(f_interp::Function, ts::AbstractTimeSeries, t::Real; indhint=nothing)
    (lb, ub) = find_bounds(ts, t, indhint)
    return (
        result  = f_interp(ts[lb], ts[ub], t), 
        indhint = lb
    )
end



"""
Finds the index of the TimeRecord before and after t::Real; indhint is the first index searched for
"""
function find_bounds(s::AbstractTimeSeries, t::Real, indhint)
    earlier_than_t(x::TimeRecord) = timestamp(x) < t
    later_than_t(x::TimeRecord) = timestamp(x) > t

    (ind1, indN) = (firstindex(s), lastindex(s))

    indL = isnothing(indhint) ? ind1 : clamp(indhint, ind1, indN) #Lower bound index
    indH = indL #Upper bound index

    if later_than_t(s[indL]) #Walk backwards in time if indhint reccord occurs later
        indL = something(findprev(earlier_than_t, s, indL), ind1-1)
        indH = indL+1
        
    else #Walk forward in time if indhint reccord occurs earlier
        indH = something(findnext(later_than_t, s, indL), indN+1)
        indL = indH-1
    end

    #Previous code can go out of bounds, prevent out of bounds 
    (indL, indH) = clamp.((indL,indH), ind1, indN)
    return (indL, indH)
end

# =================================================================================================
# Core two-point interpolation algorithms
# =================================================================================================
function interp_lastval(r1::TimeRecord, r2::TimeRecord, t::Real)
    usefirst = t < timestamp(r2)
    r0 = ifelse(usefirst, r1, r2)
    return TimeRecord(t, value(r0)*1.0)
end

function interp_linear(r1::TimeRecord, r2::TimeRecord, t::Real)
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


