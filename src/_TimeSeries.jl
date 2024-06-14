# =======================================================================================
# Abstract interface for timeseries
# =======================================================================================
abstract type AbstractTimeSeries{T} <: AbstractVector{TimeRecord{T}} end

#Indexing where sorting isn't an issue
Base.getindex(ts::AbstractTimeSeries, ind::Integer) = getindex(ts.records, ind)
Base.getindex(ts::T, ind::Colon) where T <: AbstractTimeSeries = T(getindex(ts.records, ind), issorted=true)
Base.getindex(ts::T, ind::AbstractVector{Bool}) where T <: AbstractTimeSeries = T(getindex(ts.records, ind), issorted=true)
Base.getindex(ts::T, ind::UnitRange) where T <: AbstractTimeSeries = T(getindex(ts.records, ind), issorted=true)

#All other indexing where sorting may be an issue
function Base.getindex(ts::T, ind) where T <: AbstractTimeSeries 
    return T(getindex(ts.records, ind), issorted=issorted(ind))
end

Base.setindex!(ts::AbstractTimeSeries, x, ind) = setindex!(ts.records, x, ind)
Base.size(ts::AbstractTimeSeries)           = (length(ts.records),)
Base.firstindex(ts::AbstractTimeSeries)     = 1
Base.lastindex(ts::AbstractTimeSeries)      = length(ts.records)
Base.push!(ts::AbstractTimeSeries, r)       = push!(ts.records, r)
Base.sort!(ts::AbstractTimeSeries)          = sort!(ts.records)
Base.values(ts::AbstractTimeSeries)         = value.(ts.records)

timestamps(ts::AbstractTimeSeries)          = timestamp.(ts.records)
dropnan(ts::AbstractTimeSeries{<:Real})     = dropnan!(deepcopy(ts))

function dropnan!(ts::AbstractTimeSeries{<:Real}) 
    filter!(x->!isnan(value(x)), ts.records)
    return ts
end



recordtype(::Type{AbstractTimeSeries{T}}) where T = T
recordtype(ts::AbstractTimeSeries{T}) where T = T

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
StatefulTimeSeries(ts::TimeSeries{T}) where T = StatefulTimeSeries{T}(ts.records, Ref(1), issorted=true)
StatefulTimeSeries(t::AbstractVector{Real}, v::AbstractVector{T}) where T = StatefulTimeSeries(TimeSeries(t,v))

current_value(ts::StatefulTimeSeries) = ts[ts.current[]]
set_current_index!(ts::StatefulTimeSeries, ind::Integer) = Base.setindex!(ts.ind, ind)
increment_index!(ts::StatefulTimeSeries) = set_current_index!(ts, ts.current[]+1)

#Takes increments the current value and returns the next one
function take_next!(ts::StatefulTimeSeries)
    increment_index!(ts)
    return current_value(ts)
end



