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
timestamps(ts::AbstractTimeSeries)  = map(timestamp, ts)
datetimes(ts::AbstractTimeSeries)   = map(datetime, ts)
unixtimes(ts::AbstractTimeSeries)   = map(unixtime, ts)
Base.values(ts::AbstractTimeSeries) = map(value, ts)
Base.Vector(ts::AbstractTimeSeries) = collect(ts)

valuetype(::Type{<:AbstractTimeSeries{T}}) where T = T
valuetype(ts::AbstractTimeSeries{T}) where T = T

#Indexing where sorting isn't an issue
import Base.Fix1

#Mandatory methods for all timeseries
Base.length(ts::AbstractTimeSeries)      = length(ts.records)
Base.firstindex(ts::AbstractTimeSeries)  = firstindex(ts.records)
Base.lastindex(ts::AbstractTimeSeries)   = lastindex(ts.records)
Base.getindex(ts::AbstractTimeSeries, ind::Integer) = getindex(ts.records, ind)

#Optional methods that can be inferred from basic methods
Base.size(ts::AbstractTimeSeries) = (length(ts),)
Base.getindex(ts::AbstractTimeSeries, ind::Colon) = TimeSeries(map(Fix1(getindex, ts), firstindex(ts):lastindex(ts)), issorted=true)
Base.getindex(ts::AbstractTimeSeries, ind::AbstractVector{Bool}) = TimeSeries(map(Fix1(getindex, ts), (firstindex(ts):lastindex(ts))[ind]), issorted=true)
Base.getindex(ts::AbstractTimeSeries, Δt::TimeInterval) = ts[findinner(ts, Δt)]
Base.getindex(ts::AbstractTimeSeries, ind::AbstractVector) = TimeSeries(map(Fix1(getindex, ts), ind), issorted=issorted(ind))

#Set index basesd on value only (maintains the same timestamp to guarantee sorting)
function Base.setindex!(ts::AbstractTimeSeries{T}, x::Any, ind::Integer) where T 
    setindex!(records(ts), TimeRecord(timestamp(ts[ind]), convert(T,x)), ind)
    return ts 
end

#Sets multiple indices based on value only
function Base.setindex!(ts::AbstractTimeSeries{T}, X::Any, inds::AbstractVector{<:Integer}) where T
    Base.setindex_shape_check(X, length(inds))
    for (count, ind) in enumerate(inds)
        x = convert(T, X[begin + (count-1)])
        setindex!(records(ts), TimeRecord(timestamp(ts[ind]), x), ind)
    end
    return ts 
end

#Set index checks for timestamp equality, but other wise deletes element [i] and uses that as the insertion hint
function Base.setindex!(ts::AbstractTimeSeries{T}, r::TimeRecord, ind::Integer) where T
    #Get adjacent timestamp, use NaN if out of range
    ub = ifelse((ind+1) <= lastindex(ts), timestamp(ts[min(ind+1, end)]), NaN)
    lb = ifelse((ind-1) >= firstindex(ts), timestamp(ts[max(ind-1, begin)]), NaN)
    t  = timestamp(r)

    #Check that the timestamp is inside the boundaries (with NaNs being a pass)
    if !(t<lb) & !(ub<t) 
        setindex!(records(ts), r, ind)
    else
        error("Cannot insert record $(r) because it is out-of-order $((lb, t, ub)). If order is not guaranteed, use 'deleteat!(ts, ind); push!(ts, r)'")
    end
    return ts
end

function Base.setindex!(ts::AbstractTimeSeries{T}, X::AbstractTimeSeries, inds::AbstractVector{<:Integer}) where T
    Base.setindex_shape_check(X, length(inds))
    for (count, ind) in enumerate(inds)
        setindex!(ts, X[begin + (count-1)], ind)
    end
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
keeplatest!(ts::AbstractTimeSeries, t::DateTime) = keeplatest!(ts, datetime2timestamp(t))


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
TimeInterval(ts::AbstractTimeSeries) = TimeInterval(timestamp.((ts[begin],ts[end]))...)

# =======================================================================================
# Basic Timeseries (only assumes sorted)
# =======================================================================================
"""
Constructs a time series from time records, will sort input in-place unless issorted=false
"""
struct TimeSeries{T} <: AbstractTimeSeries{T}
    records :: Vector{TimeRecord{T}}
    function TimeSeries{T}(records::AbstractVector{<:TimeRecord}; issorted=false) where T
        newseries = new{T}(records)
        if !issorted
            filter!(x->!isnan(timestamp(x)), newseries.records)
            sort!(newseries.records)
        end
        return newseries
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

Base.convert(::Type{TimeSeries{T}}, v::TimeSeries) where T = TimeSeries{T}(records(v), issorted=true)
Base.convert(::Type{TimeSeries{T}}, v::Vector{<:TimeRecord}) where T = TimeSeries{T}(v)
Base.convert(::Type{V}, v::TimeSeries) where V<:Vector{<:TimeRecord} = convert(V, records(v))
Base.sort!(ts::TimeSeries) = sort!(ts.records)

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
function Base.merge(f::Union{Function,Type}, vt::AbstractVector{<:Real}, ts1::AbstractTimeSeries, tsN::AbstractTimeSeries...; order=0)
    vts = (ts1, tsN...)
    indhints = initialhint.(vts, vt[1])
    interpolated(t::Real) = map((ts,hint)->interpolate(ts, t, order=order, indhint=hint), vts, indhints)
    return TimeSeries(map(t->TimeRecord(t, f(interpolated(t)...)), vt))
end

function Base.merge(vt::AbstractVector{<:Real}, ts1::AbstractTimeSeries, tsN::AbstractTimeSeries...; order=0)
    return merge(tuple, vt, ts1, tsN..., order=order)
end

"""
Merges a set of timeseries though timestamp union
"""
function Base.merge(f::Union{Function,Type}, ts1::AbstractTimeSeries, tsN::AbstractTimeSeries...; order=0)
    return merge(f, timestamp_union(ts1, tsN...), ts1, tsN..., order=order)
end

function Base.merge(ts1::AbstractTimeSeries, tsN::AbstractTimeSeries...; order=0) 
    return merge(timestamp_union(ts1, tsN...), ts1, tsN..., order=order)
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
@recipe function f(ts::AbstractTimeSeries; use_dates=true)
    if !use_dates
        return (timestamps(ts), values(ts))
    else
        xrot --> -10

        dt = diff(TimeInterval(ts))
        if dt < 24*3600
            return (Time.(datetime.(ts)), values(ts))
        else
            return (datetimes(ts), values(ts))
        end
    end
end