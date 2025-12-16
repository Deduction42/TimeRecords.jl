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
abstract type AbstractRegularTimeSeries{T} <: AbstractTimeSeries{T} end


# =======================================================================================
# Basic Timeseries (only assumes sorted)
# =======================================================================================
"""
struct TimeSeries{T} <: AbstractTimeSeries{T}
    records :: Vector{TimeRecord{T}}
end

Constructs a time series from time records (sorted by timstamp with NaNs removed) 
WARNING: will sort input and remove NaNs in-place unless issorted=false
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
# Regular (only assumes sorted)
# =======================================================================================
"""
struct RegularTimeSeries{T} <: AbstractTimeSeries{T}
    timestamps :: StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}
    values :: Vector{T}
end

A regular time series (i.e. sampled at a constent "step"). Generally more efficient than a basic TimeSeries due
to stricter assumptions.
"""
struct RegularTimeSeries{T} <: AbstractRegularTimeSeries{T}
    timestamps :: StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}
    values :: Vector{T}
    RegularTimeSeries{T}(vt::AbstractRange, v::AbstractVector) where T = new{T}(vt, v)
    RegularTimeSeries(vt::AbstractRange, v::AbstractVector{T}) where T = new{T}(vt, v)
end

"""
RegularTimeSeries(ts::AbstractTimeSeries{T}, vt::AbstractRange; method=:interpolate, order=0)

Regularize a timeseries either through interpolation or averaging over the previous step
"""
function RegularTimeSeries(ts::AbstractTimeSeries{T}, vt::AbstractRange; method=:interpolate, order=0) where T
    if method == :interpolate
        return RegularTimeSeries{T}(vt, interpolate(ts, vt, order=order))
    elseif method == :average
        #'average' returns N-1 elements, so extend the time range to include the range before
        vt_avg = (first(vt)-step(vt)):step(vt):last(vt)
        return RegularTimeSeries{T}(vt, average(ts, vt_avg, order=order))
    end
    throw(ArgumentError("Keyword 'method' only supports symbols with value ':interpolate' or ':average'"))
end

function RegularTimeSeries{T}(ts::AbstractTimeSeries, vt::AbstractRange; method=:interpolate, order=0) where T
    tsr = RegularTimeSeries(ts, vt, method=method, order=order)
    return RegularTimeSeries{T}(tsr.timestamps, tsr.values)
end


# =======================================================================================
# Timeseries views
# =======================================================================================
"""
TimeSeriesView{T, P, I, LinIndex}  <: AbstractTimeSeries{T}

View of a timeseries
"""
struct TimeSeriesView{T, P, I, LinIndex} <: AbstractTimeSeries{T}
    records :: SubArray{TimeRecord{T}, 1, P, I, LinIndex}
end

Base.view(ts::AbstractTimeSeries, ind::Any) = throw(ArgumentError("View of AbstractTimeSeries can only be indexed by a TimeInterval, ascending AbstractRange or AbstractVector{Bool}"))
Base.view(ts::AbstractTimeSeries, Δt::TimeInterval) = TimeSeriesView(view(records(ts), findinner(ts, Δt)))
Base.view(ts::AbstractTimeSeries, ind::AbstractRange) = issorted(ind) ? TimeSeriesView(view(records(ts), ind)) : throw(ArgumentError("Range must be ascending"))
Base.view(ts::AbstractTimeSeries, ind::AbstractVector{Bool}) = TimeSeriesView(view(records(ts), ind))


"""
RegularSeriesView{T, P, I, LinIndex}  <: AbstractTimeSeries{T}

View of a regular timeseries
"""
struct RegularTimeSeriesView{T, P, I, LinIndex} <: AbstractRegularTimeSeries{T}
    timestamps :: StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}
    values :: SubArray{T, 1, P, I, LinIndex}
end

Base.view(ts::AbstractRegularTimeSeries, ind::AbstractRange) = issorted(ind) ? RegularTimeSeriesView(ts.timestamps[ind], view(ts.values, ind)) : throw(ArgumentError("Range must be ascending"))
Base.view(ts::AbstractRegularTimeSeries, Δt::TimeInterval) = view(ts, findinner(ts, Δt))
Base.view(ts::AbstractRegularTimeSeries, ind::AbstractVector{Bool}) = throw(ArgumentError("View of RegularTimeSeries can only constructed with a TimeInterval or ascending AbstractRange"))


# =======================================================================================
# Generic timeseries functions
# =======================================================================================
TimeInterval(ts::AbstractTimeSeries) = TimeInterval(timestamp.((ts[begin],ts[end]))...)


"""
records(ts::AbstractTimeSeries)

Generate a vector of time records from the TimeSeries 
"""
records(ts::AbstractTimeSeries) = ts.records
records(ts::AbstractRegularTimeSeries) = throw(ArgumentError("records(ts) not supported for RegularTimeSeries, due to possible unintended side-effects. Use 'timestamps', 'values' or 'getindex' instead"))

"""
timestamps(ts::AbstractTimeSeries)

Generate a vector of floating point timestamps (in seconds) from a timeseries
(due to arbitrary offsets, this may not be Unix, use `unixstamps` for this instead)
"""
timestamps(ts::AbstractTimeSeries) = map(timestamp, ts)
timestamps(ts::AbstractRegularTimeSeries) = ts.timestamps

"""
datetimes(ts::AbstractTimeSeries)

Generate a vector of datetimes from a timeseries
"""
datetimes(ts::AbstractTimeSeries) = map(datetime, ts)
datetimes(ts::AbstractRegularTimeSeries) = timestamp2datetime(first(ts.timestamps)):Nanosecond(round(step(ts.timestamps)*1e9)):timestamp2datetime(last(ts.timestamps))

"""
unixtimes(ts::AbstractTimeSeries)

Generate a vector of datetimes from a timeseries
"""
unixtimes(ts::AbstractTimeSeries) = map(unixtime, ts)
unixtimes(ts::AbstractRegularTimeSeries) = timestamp2unix(first(ts.timestamps)):step(ts.timestamps):timestamp2unix(last(ts.timestamps))

"""
values(ts::AbstractTimeSeries)

Generate a vector of values from a timeseries 
"""
Base.values(ts::AbstractTimeSeries) = map(value, ts)
Base.values(ts::AbstractRegularTimeSeries) = ts.values

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

#Special case for regular timeseries
Base.length(ts::AbstractRegularTimeSeries)       = length(ts.timestamps)
Base.firstindex(ts::AbstractRegularTimeSeries)   = firstindex(ts.timestamps)
Base.lastindex(ts::AbstractRegularTimeSeries)    = lastindex(ts.timestamps)
Base.getindex(ts::AbstractRegularTimeSeries, ind::Integer) = TimeRecord(getindex(ts.timestamps, ind), getindex(ts.values, ind))

#Optional methods that can be inferred from basic methods
Base.size(ts::AbstractTimeSeries) = (length(ts),)
Base.getindex(ts::AbstractTimeSeries, ind::Colon) = TimeSeries(map(Fix1(getindex, ts), firstindex(ts):lastindex(ts)), issorted=true)
Base.getindex(ts::AbstractTimeSeries, ind::AbstractVector{Bool}) = TimeSeries(map(Fix1(getindex, ts), (firstindex(ts):lastindex(ts))[ind]), issorted=true)
Base.getindex(ts::AbstractTimeSeries, Δt::TimeInterval) = ts[findinner(ts, Δt)]
Base.getindex(ts::AbstractTimeSeries, ind::AbstractVector{<:Integer}) = TimeSeries(map(Fix1(getindex, ts), ind), issorted=issorted(ind))

#Cases for regular timeseries
Base.getindex(ts::AbstractRegularTimeSeries, ind::AbstractRange) = RegularTimeSeries(ts.timestamps[ind], ts.values[ind])

#Set index basesd on value only (maintains the same timestamp to guarantee sorting)
function Base.setindex!(ts::AbstractTimeSeries{T}, x::Any, ind::Integer) where T 
    setindex!(ts.records, TimeRecord(timestamp(ts[ind]), convert(T,x)), ind)
    return ts 
end

function Base.setindex!(ts::AbstractRegularTimeSeries{T}, x::Any, ind::Integer) where T
    setindex!(ts.values, x, ind)
    return ts 
end 

#Sets multiple indices based on value only
function Base.setindex!(ts::AbstractTimeSeries{T}, X::Any, inds::AbstractVector{<:Integer}) where T
    Base.setindex_shape_check(X, length(inds))
    for (count, ind) in enumerate(inds)
        x = convert(T, X[begin + (count-1)])
        setindex!(ts, TimeRecord(timestamp(ts[ind]), x), ind)
    end
    return ts 
end

#Set index checks to make sure overwritten timestamp is in order
function Base.setindex!(ts::AbstractTimeSeries{T}, r::TimeRecord, ind::Integer) where T
    #Get adjacent timestamp, use NaN if out of range
    ub = ifelse((ind+1) <= lastindex(ts), timestamp(ts[min(ind+1, end)]), NaN)
    lb = ifelse((ind-1) >= firstindex(ts), timestamp(ts[max(ind-1, begin)]), NaN)
    t  = timestamp(r)

    #Check that the timestamp is inside the boundaries (with NaNs being a pass)
    if !(t<lb) & !(ub<t) 
        setindex!(ts.records, r, ind)
    else
        throw(ArgumentError("Cannot insert record $(r) because it is out-of-order $((lb, t, ub)). If order is not guaranteed, use 'deleteat!(ts, ind); push!(ts, r)'"))
    end
    return ts
end

#Set index on RegularTimeSeries must check for timestamp equality
function Base.setindex!(ts::AbstractRegularTimeSeries{T}, r::TimeRecord, ind::Integer) where T
    if timestamp(r) == ts.timestamps[ind]
        ts.values[ind] = value(r)
        return ts
    else
        throw(ArgumentError("Cannot insert record $(r) because its timestamp is not equal to the original ($(timestamp2datetime(ts.timestamps[ind])))"))
    end
end

#Set multiple indices from a timeseries (inner call does the in-order timestamp check)
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
Base.deleteat!(ts::AbstractRegularTimeSeries, ind) = throw(ArgumentError("deleteat!(ts, ...) not supported for regular timeseries"))

function Base.keepat!(ts::AbstractTimeSeries, inds)
    keepat!(records(ts), inds)
    return ts
end
Base.keepat!(ts::AbstractRegularTimeSeries, inds) = throw(ArgumentError("keepat!(ts, ...) not supported for regular timeseries"))

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
Base.push!(ts::AbstractRegularTimeSeries, tr::TimeRecord; indhint=nothing) = throw(ArgumentError("push!(ts, ...) not supported for regular time series"))

dropnan(ts::AbstractTimeSeries{<:Number}) = dropnan!(ts[:])
function dropnan!(ts::AbstractTimeSeries{<:Number}) 
    filter!(x->!isnan(value(x)), records(ts))
    return ts
end
dropnan!(ts::AbstractRegularTimeSeries, tr::TimeRecord; indhint=nothing) = throw(ArgumentError("dropnan!(ts, ...) not supported for regular time series"))


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
mapvalues(f, ts::AbstractTimeSeries) = TimeSeries([TimeRecord(timestamp(r), f(value(r))) for r in ts], issorted=true)
mapvalues(f, ts::AbstractRegularTimeSeries) = RegularTimeSeries(ts.timestamps, map(f, ts.values))


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