# =======================================================================================
# Abstract interface for timeseries
# =======================================================================================
include("_TimeRecord.jl")

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

Base.eltype(::Type{<:AbstractTimeSeries{T}}) where T = T
Base.eltype(ts::AbstractTimeSeries{T}) where T = T

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

Base.view(ts::AbstractTimeSeries, ind::Any) = error("View of AbstractTimeSeries can only be indexed by a UnitRange or AbstractVector{Bool}")
Base.view(ts::AbstractTimeSeries, Δt::TimeInterval) = TimeSeriesView(view(records(ts), findinner(ts, Δt)))
Base.view(ts::AbstractTimeSeries, ind::UnitRange) = TimeSeriesView(view(records(ts), ind))
Base.view(ts::AbstractTimeSeries, ind::AbstractVector{Bool}) = TimeSeriesView(view(records(ts), ind))


# =======================================================================================
# Merging functionality through extrapolation
# =======================================================================================
"""
Merges a set of timeseries to a common set of timestamps through extrapolation
Produces a StaticVector for each timestamp
"""
function Base.merge(t::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)
    ts_extrap = map(ts->interpolate(ts,t, order=order), vts)
    return _merge_records(ts_extrap...)
end

function Base.merge(f::Union{Function,Type}, t::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)
    ts_extrap = map(ts->interpolate(ts,t, order=order), vts)
    return _merge_records(f, ts_extrap...)
end

function _merge_records(f::Union{Function,Type}, uts::AbstractTimeSeries...)
    return TimeSeries([merge(f, r...) for r in zip(uts...)])
end

function _merge_records(uts::AbstractTimeSeries...)
    return TimeSeries([merge(r...) for r in zip(uts...)])
end

#=
# =======================================================================================
# Stateful timeseries
# =======================================================================================
"""
Timeseries that contains a reference to the latest value accessed
"""
@kwdef struct StatefulTimeSeries{T} <: AbstractTimeSeries{T}
    records :: Vector{TimeRecord{T}}
    current :: Base.RefValue{Int64}
    function StatefulTimeSeries{T}(records::AbstractVector{TimeRecord{T}}, ind::Base.RefValue=Ref(1); issorted=false) where T
        if issorted
            return new{T}(records, ind)
        else
            return new{T}(sort!(records), ind)
        end
    end
end

StatefulTimeSeries(ts::AbstractVector{TimeRecord{T}}) where T = StatefulTimeSeries{T}(ts, Ref(1))
StatefulTimeSeries(ts::TimeSeries{T}) where T = StatefulTimeSeries{T}(records(ts), Ref(1), issorted=true)
StatefulTimeSeries(t::AbstractVector{Real}, v::AbstractVector{T}) where T = StatefulTimeSeries(TimeSeries(t,v))

current_value(ts::StatefulTimeSeries) = ts[ts.current[]]
set_current_index!(ts::StatefulTimeSeries, ind::Integer) = Base.setindex!(ts.ind, ind)
increment_index!(ts::StatefulTimeSeries) = set_current_index!(ts, ts.current[]+1)

#Takes increments the current value and returns the next one
function take_next!(ts::StatefulTimeSeries)
    increment_index!(ts)
    return current_value(ts)
end

=#

