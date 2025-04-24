# =======================================================================================
# Abstract interface for timeseries
# =======================================================================================

"""
AbstractTimeSeries{T} <: AbstractVector{TimeRecord{T}}

A sorted AbstractVector{TimeRecord{T}}, in ascending order by timestamp
All children of AbstractTimeSeries must support the 'records(ts)' function
By default, records(ts::AbstractTimeSeries) = ts.records
"""
abstract type AbstractTimeSeries{T} <: AbstractVector{TimeRecord{T}} end

records(ts::AbstractTimeSeries)     = ts.records
timestamps(ts::AbstractTimeSeries)  = timestamp.(records(ts))
datetimes(ts::AbstractTimeSeries)   = datetime.(records(ts))  
Base.values(ts::AbstractTimeSeries) = value.(records(ts))
Base.Vector(ts::AbstractTimeSeries) = Vector(records(ts))

valuetype(::Type{<:AbstractTimeSeries{T}}) where T = T
valuetype(ts::AbstractTimeSeries{T}) where T = T

#Indexing where sorting isn't an issue
Base.getindex(ts::AbstractTimeSeries, ind::Integer) = getindex(records(ts), ind)
Base.getindex(ts::T, ind::Colon) where T <: AbstractTimeSeries = T(getindex(records(ts), ind), issorted=true)
Base.getindex(ts::T, ind::AbstractVector{Bool}) where T <: AbstractTimeSeries = T(getindex(records(ts), ind), issorted=true)
Base.getindex(ts::T, ind::UnitRange) where T <: AbstractTimeSeries = T(getindex(records(ts), ind), issorted=true)
Base.getindex(ts::T, Δt::TimeInterval) where T <: AbstractTimeSeries = T(getindex(records(ts), findinner(ts, Δt)), issorted=true)

#All other indexing where sorting may be an issue
function Base.getindex(ts::T, ind) where T <: AbstractTimeSeries 
    return T(getindex(records(ts), ind), issorted=issorted(ind))
end

#Set index basesd on value only (maintains the same timestamp to guarantee sorting)
function Base.setindex!(ts::AbstractTimeSeries{T}, x, ind::Integer) where T 
    setindex!(records(ts), TimeRecord(timestamp(ts[ind]), T(x)), ind)
    return ts 
end

#Sets multiple indices based on value only
function Base.setindex!(ts::AbstractTimeSeries{T}, X::AbstractArray, inds::AbstractVector) where T
    Base.setindex_shape_check(X, length(inds))
    ix0 = firstindex(X)
    for (count, ind) in enumerate(inds)
        x = T(X[ix0+count-1])
        setindex!(records(ts), TimeRecord(timestamp(ts[ind]), x), ind)
    end
    return ts 
end

#Set index checks for timestamp equality, but other wise deletes element [i] and uses that as the inertion hint
function Base.setindex!(ts::AbstractTimeSeries{T}, r::TimeRecord, ind::Integer) where T
    if timestamp(r) == timestamp(ts[ind])
        setindex!(records(ts), r, ind)
    else
        deleteat!(ts, ind)
        push!(ts, r, indhint=ind)
    end
    return ts
end

#Set multiple indices and then sort the timeseries
function Base.setindex!(ts::AbstractTimeSeries{T}, vr::AbstractVector{<:TimeRecord}, ind::AbstractVector) where T
    setindex!(records(ts), vr, ind)
    sort!(ts)
    return ts
end

function Base.fill!(ts::AbstractTimeSeries, x)
    for ii in eachindex(ts)
        ts[ii] = x
    end
    return ts
end

function Base.deleteat!(ts::AbstractTimeSeries, ind)
    deleteat!(records(ts), ind)
    return ts
end

function Base.keepat!(ts::AbstractTimeSeries, inds)
    keepat!(records(ts), inds)
    return ts
end

Base.length(ts::AbstractTimeSeries)      = length(records(ts))
Base.size(ts::AbstractTimeSeries)        = (length(records(ts)),)
Base.firstindex(ts::AbstractTimeSeries)  = firstindex(records(ts))
Base.lastindex(ts::AbstractTimeSeries)   = lastindex(records(ts))
Base.sort!(ts::AbstractTimeSeries)       = sort!(records(ts))

"""
push!(ts::TimeSeries, tr::TimeRecord)

Adds a TimeRecord (tr) to the TimeSeries(ts) by inserting it in order
"""
function Base.push!(ts::AbstractTimeSeries, tr::TimeRecord; indhint=nothing)
    if isempty(records(ts)) || (ts[end] <= tr)
        push!(records(ts), tr)
    elseif (tr <= ts[begin])
        pushfirst!(records(ts), tr)
    else
        bounds = findbounds(ts, timestamp(tr), indhint)
        insert!(records(ts), bounds[end], tr)
    end
    return ts 
end
  
dropnan(ts::AbstractTimeSeries{<:Number}) = dropnan!(deepcopy(ts))
function dropnan!(ts::AbstractTimeSeries{<:Number}) 
    filter!(x->!isnan(value(x)), records(ts))
    return ts
end

"""
keeplatest!(ts::AbstractTimeSeries)

Delets all elements of 'ts' except the last one
"""
function keeplatest!(ts::AbstractTimeSeries)
    if isempty(ts)
        return ts
    else
        keepat!(records(ts), length(records(ts)))
        return ts
    end
end

"""
keeplatest!(ts::AbstractTimeSeries, t)

Deletes all elements in 'ts' that occurs before 't' except the last one
"""
function keeplatest!(ts::AbstractTimeSeries, t::Real)
    if isempty(ts)
        return ts 
    else
        ind = searchsortedlast(ts, TimeRecord(t,ts[begin]))
        keepat!(records(ts), max(ind, firstindex(ts)):lastindex(ts))
        return ts
    end
end
keeplatest!(ts::AbstractTimeSeries, t::DateTime) = keeplatest!(ts, datetime2unix(t))


"""
mapvalues(f, ts::AbstractTimeSeries) -> TimeSeries

Maps callable "f" to each of the values in a timeseries, returns a TimeSeries with the same timestamps but modified values
"""
mapvalues(f, ts::AbstractTimeSeries)  = TimeSeries([TimeRecord(timestamp(r), f(value(r))) for r in ts], issorted=true)


"""
mapvalues!(f, ts::AbstractTimeSeries) -> ts

Maps callable "f" to each of the values in ts, modifying it in-place. Output must be the same type as input
"""
function mapvalues!(f, ts::AbstractTimeSeries)
    for ii in eachindex(ts)
        ts[ii] = f(value(ts[ii]))
    end
    return ts
end

"""
TimeInterval(ts::AbstractTimeSeries)

Creates a time interval based on the beginning and end of the timeseries
"""
TimeInterval(ts::AbstractTimeSeries) = TimeInterval(timestamp.((ts[begin],ts[end])))

# =======================================================================================
# Regular timeseries
# =======================================================================================
"""
Constructs a time series from time records, will sort input in-place unless issorted=false
"""
struct TimeSeries{T} <: AbstractTimeSeries{T}
    records :: Vector{TimeRecord{T}}
    function TimeSeries{T}(records::AbstractVector{TimeRecord{T}}; issorted=false) where T
        if issorted
            return new{T}(records)
        else
            return new{T}(sort!(records))
        end
    end
end

"""
Constructs a time series from two vectors (unix timestamps, values)
"""
TimeSeries(v::AbstractVector{TimeRecord{T}}; issorted=false) where T = TimeSeries{T}(v, issorted=issorted)
TimeSeries(t::AbstractVector{<:Real}, v::AbstractVector{T}; issorted=false) where T = TimeSeries{T}(TimeRecord{T}.(t, v), issorted=issorted)
TimeSeries(t::AbstractVector{<:DateTime}, v::AbstractVector{T}; issorted=false) where T = TimeSeries{T}(TimeRecord{T}.(t, v), issorted=issorted)
TimeSeries{T}(t::AbstractVector, v::AbstractVector; issorted=false) where T = TimeSeries{T}(TimeRecord{T}.(t,v), issorted=issorted)
TimeSeries{T}() where T = TimeSeries{T}(TimeRecord{T}[], issorted=true)

# =======================================================================================
# Timeseries views
# =======================================================================================
"""
View of a timeseries
"""
struct TimeSeriesView{T, P, I, LinIndex} <: AbstractTimeSeries{T}
    records :: SubArray{TimeRecord{T}, 1, P, I, LinIndex}
end

Base.view(ts::AbstractTimeSeries, ind::Any) = throw(ArgumentError("View of AbstractTimeSeries can only be indexed by a UnitRange or AbstractVector{Bool}"))
Base.view(ts::AbstractTimeSeries, Δt::TimeInterval) = TimeSeriesView(view(records(ts), findinner(ts, Δt)))
Base.view(ts::AbstractTimeSeries, ind::UnitRange) = TimeSeriesView(view(records(ts), ind))
Base.view(ts::AbstractTimeSeries, ind::AbstractVector{Bool}) = TimeSeriesView(view(records(ts), ind))


# =======================================================================================
# Merging functionality through extrapolation
# =======================================================================================
"""
    Base.merge(f::Union{Function,Type}, vt::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)

Merges a set of timeseries to a common set of timestamps through interpolation and applies 'f' to the resulting row
If 'f' is not provided, 'tuple' is used
"""
function Base.merge(f::Union{Function,Type}, vt::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)
    indhints = initialhint.(vts, vt[1])
    interpolated(t::Real) = map((ts,hint)->interpolate(ts, t, order=order, indhint=hint), vts, indhints)
    return TimeSeries(map(t->TimeRecord(t, f(interpolated(t)...)), vt))
end

function Base.merge(vt::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)
    return merge(tuple, vt, vts..., order=order)
end

"""
Merges a set of timeseries though timestamp union
"""
function Base.merge(f::Union{Function,Type}, vts::AbstractTimeSeries...; order=0) 
    return merge(f, timestamp_union(vts...), vts..., order=order)
end

function Base.merge(vts::AbstractTimeSeries...; order=0) 
    return merge(timestamp_union(vts...), vts..., order=order)
end

"""
Returns commmon timestamps for a collection of AbstractTimeSeries
"""
function timestamp_union(seriesitr)
    tsunion = Set{Float64}()
    for tseries in values(seriesitr)
        union!(tsunion, (timestamp(tr) for tr in tseries))
    end
    return sort!(collect(tsunion)) 
end

"""
Returns commmon timestamps for a set of AbstractTimeSeries
"""
function timestamp_union(vts::AbstractTimeSeries...)
    return timestamp_union(vts)
end


#Recipe for plotting timeseries
@recipe function f(ts::TimeSeries; use_dates=true)
    if !use_dates
        return (timestamps(ts), values(ts))
    else
        xrot --> 20

        dt = diff(TimeInterval(ts))
        if dt < 24*3600
            return (Time.(datetime.(ts)), values(ts))
        else
            return (datetimes(ts), values(ts))
        end
    end
end