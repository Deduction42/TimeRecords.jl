[![Build Status](https://github.com/Deduction42/TimeRecords.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Deduction42/TimeRecords.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage Status](https://coveralls.io/repos/github/Deduction42/TimeRecords.jl/badge.svg?branch=DEV)](https://coveralls.io/github/Deduction42/TimeRecords.jl?branch=DEV)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


# TimeRecords
A common problem encountered with timeseries analysis is that most multivariate algorithms require complete observations (all components) for a given timestamp, but in many situations, data from different components are sampled at different timestamps. This is particularly common with industrial historians and streaming IoT applications based on MQTT protocols or similar where data arrives one record at a time (in somewhat chronological order), from different devices at different sampling rates. This package matches the record-driven format common in these environments and supports common operations used to transform this data into formats commonly required by multivariate time series algorithms. As such, it is not a competitor to other time series packages like TimeSeries.jl, but complementary, providing operations that can transform record-driven data into formats they can use. These operations include:
- Interpolation
- Time-Weighted Integration
- Time-Weighted Averaging
- Merge-by-interpolation
- Streaming data collection

The basic building blocks of this package comprise of

1. `TimeRecord{T}` (a value of type `T` with a timestamp attached)
2. `AbstractTimeSeries{T}` (an `AbstractVector{TimeRecord{T}}` that is always sorted based on time)

For multivariate observations, the recommended DataType for each element is `SVector{N}`, but elements can consist of any custom object. Nevertheless, functionality may be limited on certain datatypes: 
 - Zeroth-order tnterpolation supports`TimeSeries{T}` of any element type. 
 - First-order interpolation requires the ability to add `T` and multiply `T` by floats. 
 - Integration and averaging also requires supporting the method `zero(T)` which is why `Vector` may not be a great element choice

This package also includes a capstone datatype called `TimeSeriesCollector` which can be used to collect streaming data, organize it by label, and periodically send it as chunks to any function/algorithm with the following argument structure: 
```julia
f(data::Dict{String,TimeSeries{T}}, interval::TimeInterval) where T
```
This provides a convenient way to implement timeseries algorithms that interact with a message-based service like [MQTT](https://github.com/denglerchr/Mosquitto.jl) or [NATS](https://github.com/jakubwro/NATS.jl).

## TimeRecord
```julia
struct TimeRecord{T} <: AbstractTimeRecord{T}
    t :: Float64
    v :: T
end
```
A wrapper that attaches a unix timestap to a value. Timestamps are stored internally as Float64 (enabling faster and easier numeric computations like intergrals) but are displayed as DateTime.
```julia
julia> tr = TimeRecord(0, 1.1)
TimeRecord{Float64}(t=1970-01-01T00:00:00, v=1.1)

julia> tr = TimeRecord(DateTime(2014, 09, 15), "Here's a random date")
TimeRecord{String}(t=2014-09-15T00:00:00, v="Here's a random date")
```
You can retrieve timestamps using `timestamp(tr)` or `datetime(tr)`
```julia
julia> timestamp(tr)
1.4107392e9

julia> datetime(tr)
2014-09-15T00:00:00
```
values are retrieved using `value(tr)`
```julia
julia> value(tr)
"Here's a random date"
```

## TimeInterval
An object which stores two timestamps as a sorted vector. This is useful for integrals or queries on timestamps. Constructors can use either Real or DateTime as inputs.
```julia
julia> dt = TimeInterval(0, 5); dt = TimeInterval(0=>5)
1970-01-01T00:00:00 => 1970-01-01T00:00:05
```

## TimeSeries
A vector of time records in chronological order, which among other things, supports indexing using time intervals.

```julia
julia> ts = TimeSeries([1,2,3,4,5],[1,2,3,4,5])
5-element TimeSeries{Int64}:
    TimeRecord{Int64}(t=1970-01-01T00:00:01, v=1)
    TimeRecord{Int64}(t=1970-01-01T00:00:02, v=2)
    TimeRecord{Int64}(t=1970-01-01T00:00:03, v=3)
    TimeRecord{Int64}(t=1970-01-01T00:00:04, v=4)
    TimeRecord{Int64}(t=1970-01-01T00:00:05, v=5)

julia> ts[TimeInterval(0=>3.1)]
3-element TimeSeries{Int64}:
    TimeRecord{Int64}(t=1970-01-01T00:00:01, v=1)
    TimeRecord{Int64}(t=1970-01-01T00:00:02, v=2)
    TimeRecord{Int64}(t=1970-01-01T00:00:03, v=3)
```
Some additional notes on TimeSeries and its chronological API
-  `ts[dt::TimeInterval]` will return any time series data points on or inside the time interval
-  `push!(ts::AbstractTimeSeries, r::TimeRecord)` will insert `r` into `ts` while maintaining chronological order
-  `setindex(ts::AbstractTimeSeries, x::Any, ind)` will only overwrite the value, keeping the timestamp the same 
-  `setindex(ts::AbstractTimeSeries, r::TimeRecord, ind)` replaces the value if the timestamps are equal, otherwise it uses `deleteat!(ts, ind)` then `push!(ts, r, indhint=ind)` (in order to guarantees sorting)
-  `setindex(ts::AbstractTimeSeries, vr::AbstractVector{TimeRecord}, ind)` overwrites values in `records(ts)` and then sorts
-  `records(ts::AbstractTimeSeries)` will return the internal timeseries vector, but care must be taken with mutation in order to prevent violating the inherent chronological assumptions of the TimeSeries

This package also includes a plotting recipe to plot timeseries as `(timestamp.(ts), value.(ts))` pairs, making it convenient to plot time series and even subsections over intervals
```julia
using Plots
plot(ts)
dt = TimeInterval(DateTime("1970-01-01T00:00:01") => DateTime("1970-01-01T00:00:03"))
plot(ts[dt])
```

## RegularTimeSeries
A StepRangeLen of timestamps paired with a vector of values. This different internal storage makes calling `timestamps(ts::RegularTimeSeries)` and `values(ts::RegularTimeSeries)` more efficient than it is for `TimeSeries`. Indexing by time range is also much much more efficient as indices can be calculated due to uniform timestamp assumptions. Due to timestamps being a range, operations that mutate timestamps are not allowed (such as `push`). However, operations that only mutate values are still valid (such as `setindex!` for values only, or time records with the same timestamp).

```julia
julia> ts = RegularTimeSeries(1:5,[1,2,3,4,5])
5-element RegularTimeSeries{Int64}:
 TimeRecord{Int64}(t="1970-01-01T00:00:01", v=1)
 TimeRecord{Int64}(t="1970-01-01T00:00:02", v=2)
 TimeRecord{Int64}(t="1970-01-01T00:00:03", v=3)
 TimeRecord{Int64}(t="1970-01-01T00:00:04", v=4)
 TimeRecord{Int64}(t="1970-01-01T00:00:05", v=5)
 end


julia> ts[TimeInterval(0=>3.1)]
3-element RegularTimeSeries{Int64}:
 TimeRecord{Int64}(t="1970-01-01T00:00:01", v=1)
 TimeRecord{Int64}(t="1970-01-01T00:00:02", v=2)
 TimeRecord{Int64}(t="1970-01-01T00:00:03", v=3)
```

A convenience method `timeseries` can be used to construct the optimal timeseries type given the arguments
```julia
julia> timeseries(1:2, 1:2)
2-element RegularTimeSeries{Int64}:
 TimeRecord{Int64}(t="1970-01-01T00:00:01", v=1)
 TimeRecord{Int64}(t="1970-01-01T00:00:02", v=2)

julia> timeseries([1,2], 1:2)
2-element TimeSeries{Int64}:
 TimeRecord{Int64}(t="1970-01-01T00:00:01", v=1)
 TimeRecord{Int64}(t="1970-01-01T00:00:02", v=2)

julia> timeseries(TimeRecord.(1:2, 1:2))
2-element TimeSeries{Int64}:
 TimeRecord{Int64}(t="1970-01-01T00:00:01", v=1)
 TimeRecord{Int64}(t="1970-01-01T00:00:02", v=2)
```

## Interpolation
The first major functionality supported is interpolation. Supported interpolation methods are zero-order-hold (order=0) or linear (order=1). 

Regular interpolation uses flat-saturation if the timestamp is out of the timeseries range.

`interpolate(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)`

Strict interpolation will return a missing value if outside the range.

`strictinterp(ts::AbstractTimeSeries, t::Union{<:Real, AbstractVector{<:Real}}; order=0)`

## Integration
The second major functionality supported is integration (and averaging). Integration can be done over a simple TimeInterval, or on a vector of timestamps (where n values will result in n-1 integration intervals). 
```
average(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T
integrate(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T
accumulate(ts::AbstractTimeSeries{T}; order=1) where T
integrate(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing; order=1) where T <: Number
average(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing; order=1) where T <: Number
```
When using a single TimeInterval, you may want to set `indhint=nothing` if you are only doing a single evaluation on that timeseries (this performs a bisection search). However, if you are performing integration/averageing over multiple time intervals on the same timeseries, in order you may want to use
```
indhint=initialhint!(Ref(1), ts, t)
integrate(ts, t, indhint=indhint, order=1)
```
and re-use indhint for every subsequent evaluation. This allows the integration step to save its final search result in `indhint` giving a strong recommendation for the next step on where to start, greatly reducing the need for searching.

## Converting TimeSeries to RegularTimeSeries
One common use for interpolation/averaging is converting irregular timeseries to regularized form. RegularTimeSeries contains a convenience constructor for this purpose, using many of the same keyword arguments from the interpolation and averaging functions. When averaging, do note that the average is taken on the time interval *before* the timestamp so as not to potentially pollute the time record with *future information*.

```julia
julia> ts = TimeSeries(1:5, 1.0:5.0);
julia> RegularTimeSeries(ts, 1.5:4.5, method=:interpolate, order=1)
4-element RegularTimeSeries{Float64}:
 TimeRecord{Float64}(t="1970-01-01T00:00:01.500", v=1.5)
 TimeRecord{Float64}(t="1970-01-01T00:00:02.500", v=2.5)
 TimeRecord{Float64}(t="1970-01-01T00:00:03.500", v=3.5)
 TimeRecord{Float64}(t="1970-01-01T00:00:04.500", v=4.5)

julia> RegularTimeSeries(ts, 1.5:4.5, method=:average, order=0)
4-element RegularTimeSeries{Float64}:
 TimeRecord{Float64}(t="1970-01-01T00:00:01.500", v=1.0)
 TimeRecord{Float64}(t="1970-01-01T00:00:02.500", v=1.5)
 TimeRecord{Float64}(t="1970-01-01T00:00:03.500", v=2.5)
 TimeRecord{Float64}(t="1970-01-01T00:00:04.500", v=3.5)
```

## EpisodeBuilder
A common task for industrial timeseries analysis is identifying time periods where a certain condition is met and reporting aggregations (such as total sum, or maximum). These flagged time periods are often referred to as episodes. This package comes with tooling to make that process a bit easier. The first major object is the EpisodeBuilder:
```julia
@kwdef struct EpisodeBuilder{F1,F2,T<:AbstractEpisodeState}
    starter :: F1
    reducer :: F2
    state :: T
    start :: Base.RefValue{Float64} = Ref(NaN)
end
```
Within this object, an episode state is required; this is because the episode builder is meant to run by feeding it one record at a time, not inspecting the entire timeseries (as this is not possible for streaming, or PubSub applications). The default state is shown below:
```julia
@kwdef mutable struct EpisodeState{S,T} <: AbstractEpisodeState{S}
    totalizer  :: S
    lastrecord :: TimeRecord{T}
    startvalue :: T 
    stopvalue  :: T
end
```
One may wish to extend this with custom states, for example, if one wants to store more than one previous record at a time. However, this default is suitable for most applications, including ones that apply Julia's own reduce functions like `max`, `min`, or simple integrals.

The idea behind the `starter` function is to trigger the `reducer` once a start start criterion is met. This starter function analyzes a time record for a condition, and if the condition is met, sets the start value to the current timestamp, initializes the state, and returns the state value (instead of `nothing`). An episode is consider `started` when the `start` field is not `NaN`. An example of a starter function can be found here (this very function can be imported if desired)
```julia
function sum_above_starter(state::EpisodeState, r::TimeRecord)
    if value(r) > state.startvalue
        state.lastrecord = r 
        state.totalizer = zero(state.totalizer)
        return state.totalizer
    end 
    return nothing
end
```
The idea behind the `reducer` function is to tally the results once an episode has started. Once it has finished, the final result of the totalizer is returned (instead of `nothing`).
```julia
function sum_above_reducer(state::EpisodeState, r::TimeRecord)
    state.totalizer += integrate(state.lastrecord, r, order=0)
    state.lastrecord = r 
    return (value(r) < state.stopvalue) ? state.totalizer : nothing
end
```
In both cases, it's important to return `nothing` when no change in state is required, and that you return `state.totalizer` (or your custom state's equivalent) when a change in status is desired (such as starting/stopping). Higher-order functions in `build_episodes` will handle the status flag (which is inferred based on whether or not `start` is `NaN`). With this in mind, we can assemble the whole episode builder with the following code example (that includes units of measure from FlexUnits.jl):

```julia
using FlexUnits, .UnitRegistry
builder = EpisodeBuilder(
    starter = TimeRecords.sum_above_starter,
    reducer = TimeRecords.sum_above_reducer,
    state = EpisodeState(
        lastrecord = TimeRecord(NaN, 0.0*u"kg/hr"), 
        startvalue = 5.0*u"kg/hr", 
        stopvalue = 5.0*u"kg/hr", 
        totalizer = 0.0u"kg"
    )
)

ts = TimeSeries([
    TimeRecord(0, 0u"kg/hr"),
    TimeRecord(1, 0u"kg/hr"),
    TimeRecord(2, 6u"kg/hr"),
    TimeRecord(3602, 0u"kg/hr"),
    TimeRecord(3603, 8u"kg/hr"),
    TimeRecord(7203, 0u"kg/hr")
])

julia> episodes = build_episodes(builder, ts)
2-element Vector{Pair{TimeInterval, Quantity{Float64, StaticDims{kg}}}}:
 2020-01-01T00:00:02 => 2020-01-01T01:00:02 => 6.0 kg
 2020-01-01T01:00:03 => 2020-01-01T02:00:03 => 8.0 kg
```

## TimeSeriesCollector
A datatype that is used to collect tagged time record pairs `Pair{String, TimeRecord{T}}` and organize them as timeseries according to their labels.
```
@kwdef struct TimeSeriesCollector{T}
    interval :: Millisecond
    delay :: Millisecond
    timer :: Base.RefValue{DateTime}  = Ref(floor(now(UTC), interval))
    data  :: Dict{String, TimeSeries{T}} = Dict{String, TimeSeries{T}}()
end
```
This structure has two main tuning parameters:
1. `interval` the time interal in which data is chunked (cannot be negative); values of 0 will send data whenever the timestamp changes.
2. `delay` how long the TimeSeriesCollector waits before sending data; because data typically doesn't arrive strictly in order, adding a delay gives some time for out-of-order records to arrive, reducing the risk of dropped data.

This structure is meant to operate with the `apply!` function
```
apply!(collector::TimeSeriesCollector, tagrecord::Pair{<:String, <:TimeRecord})
```
This function adds tagrecord to the collector, returning `nothing` if the timestamp isn't large enough to trigger the timer. If the timer is triggered, the function will return a snapshot of the dataset and an evaluation interval: `NamedTuple{snapshot<:Dict, interval::TimeInterval}`. Data returned in the snapshot is deleted from the collecter (except the latest value).

This function can also be supplied with a callback function that gets called when a snapshot is produced
```
apply!(f::Function, collector::TimeSeriesCollector, tagrecord::Pair{<:String, <:TimeRecord}) 
```
Here, `apply!(f, collector, tagrecord)` also produces `nothing` when the timer isn't triggered, but it if the timer is triggered the resulting data is fed to the callback function `f` in a spawned (multithreaded) Task which is returned.

It is also possible to take data directly by supplying a timestamp instead of a time record.
```
take!(collector::TimeSeriesCollector, t::DateTime)
```
This behaves like `apply!` except no new records are added (only snapshots are returned and old data is deleted).


