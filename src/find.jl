include("_TimeSeries.jl")

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
function findinner(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing)
    bndL = extendedbounds(ts, Δt[begin], indhint)
    lb = ifelse(_equal_timestamp(ts, bndL[1], Δt[begin]), bndL[1], bndL[2])

    bndU = extendedbounds(ts, Δt[end], lb)
    ub = ifelse(_equal_timestamp(ts, bndU[2], Δt[end]), bndU[2], bndU[1])
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

function _equal_timestamp(ts::TimeSeries, ind::Integer, t::Real) 
    if firstindex(ts) <= ind <= lastindex(ts)
        return timestamp(ts[ind])==t
    else
        return false
    end
end


"""
findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint)

Finds the indices of the TimeSeries ts that surround the time interval Δt, 
If Δt is outside the time range both results will be the nearest index
"""
function findouter(ts::AbstractTimeSeries, Δt::TimeInterval, indhint=nothing)
    bndL = clampedbounds(ts, Δt[begin], indhint)
    lb = ifelse(_equal_timestamp(ts, bndL[2], Δt[begin]), bndL[2], bndL[1])

    bndU = clampedbounds(ts, Δt[end], lb)
    ub = ifelse(_equal_timestamp(ts, bndU[1], Δt[end]), bndU[1], bndU[2])
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
        return indL => indH
        
    else #Walk backwards in time if indhint reccord occurs later than t
        indL = findprev(earlier_than_t, ts, indhint)
        indH = something(indL, firstindex(ts)-1) + 1
        indH = min(indH, indN)
        return indL => indH
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
    return lb => ub
end


"""
findbounds(ts::AbstractTimeSeries, t::Real)

Finds bounding indices for timeseries (ts) at time (t) using a bisection method
"""
function findbounds(ts::AbstractTimeSeries, t::Real)
    (lb, ub) = (firstindex(ts), lastindex(ts))
    T = typeof(lb)

    if t < timestamp(ts[lb])
        return nothing=>lb
    elseif timestamp(ts[ub]) < t
        return ub => nothing
    end

    while (ub-lb) > 1
        mb = ceil(T, 0.5*(lb+ub))
        if timestamp(ts[mb]) < t
            (lb, ub) = (mb, ub)
        else
            (lb, ub) = (lb, mb)
        end
    end

    return lb => ub
end

findbounds(ts::AbstractTimeSeries, t::Real, indhint::Nothing) = findbounds(ts, t)

"""
clampedbounds(ts::AbstractTimeSeries, t::Real, indhint::RefValue{<:Integer})

Behaves like findbounds except that it always returns integer boundaries within the timeseries bounds
"""
clampedbounds(ts::AbstractTimeSeries, t::Real, indhint) = clampbounds(findbounds(ts, t, indhint))

"""
extendedbounds(ts::AbstractTimeSeries, t::Real, indhint::RefValue{<:Integer})

Behaves like findbounds except that it always returns integer boundaries within the timeseries bounds
"""
extendedbounds(ts::AbstractTimeSeries, t::Real, indhint) = extendbounds(findbounds(ts, t, indhint))


"""
clampbounds(Pair{Union{Integer,Nothing}, Union{Integer,Nothing}})

Clamps the result of findbounds so that results contain integers (not Nothing) inside the index
"""
clampbounds(t::Pair{Nothing, <:Integer})   = t[2] => t[2]
clampbounds(t::Pair{<:Integer, Nothing})   = t[1] => t[1]
clampbounds(t::Pair{<:Integer, <:Integer}) = t

"""
extendbounds(Pair{Union{Integer,Nothing}, Union{Integer,Nothing}})

Clamps the result of findbounds so that results contain integers (not Nothing) but can be outside the index
"""
extendbounds(t::Pair{Nothing, <:Integer})   = (t[2]-1) => t[2]
extendbounds(t::Pair{<:Integer, Nothing})   = t[1] => (t[1]+1)
extendbounds(t::Pair{<:Integer, <:Integer}) = t