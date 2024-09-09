# TimeRecords
Data structure framework to support record-driven (row-wise) timeseries analysis operatios allowing for easy interpolation, integration, merging and time-driven indexing.

## TimeRecord
```
struct TimeRecord{T} <: AbstractTimeRecord{T}
    t :: Float64
    v :: T
end
```
A wrapper that attaches a unix timestap to a value. Timestamps are stored internally as Float64.
```
tr = TimeRecord(0, 1.1)
>> TimeRecord{Float64}(t=1970-01-01T00:00:00, v=1.1)

tr = TimeRecord(DateTime(2014, 09, 15), "Here's a random date")
>> TimeRecord{String}(t=2014-09-15T00:00:00, v="Here's a random date")
```
You can retrieve timestamps using `timestamp(tr)` or `datetime(tr)`
```
timestamp(tr)
>> 1.4107392e9
datetime(tr)
>> 2014-09-15T00:00:00
```
values are retrieved using `value(tr)`
```
value(tr)
>> "Here's a random date"
```

## TimeInterval
An object which stores two timestamps as a sorted vector. This is useful for integrals or queries on timestamps. Constructors can use either Real or DateTime as inputs.
```
dt = TimeInterval(0, 5); dt = TimeInterval(0=>5)
>> 1970-01-01T00:00:00 => 1970-01-01T00:00:05
```

## TimeSeries
A vector of time records which among other things, supports indexing using time intervals.

```
ts = TimeSeries([1,2,3,4,5],[1,2,3,4,5])
>> 5-element TimeSeries{Int64}:
    TimeRecord{Int64}(t=1970-01-01T00:00:01, v=1)
    TimeRecord{Int64}(t=1970-01-01T00:00:02, v=2)
    TimeRecord{Int64}(t=1970-01-01T00:00:03, v=3)
    TimeRecord{Int64}(t=1970-01-01T00:00:04, v=4)
    TimeRecord{Int64}(t=1970-01-01T00:00:05, v=5)

ts[TimeInterval(0=>3.1)]
>> 3-element TimeSeries{Int64}:
    TimeRecord{Int64}(t=1970-01-01T00:00:01, v=1)
    TimeRecord{Int64}(t=1970-01-01T00:00:02, v=2)
    TimeRecord{Int64}(t=1970-01-01T00:00:03, v=3)
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
time_averages(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T
time_integrals(ts::AbstractTimeSeries{T}, vt::AbstractVector{<:Real}; order=1) where T
cumulative_integral(ts::AbstractTimeSeries{T}; order=1) where T
time_integral(ts::AbstractTimeSeries{T}, Δt::TimeInterval, indhint=nothing; order=1) where T <: Number
```
## Merging
In many cases, it's desirable to have multivariate data where a full multivariate observation exists for every desired timestamp. However, it's often the case that different timestamps are available for different variables. The merging functionality finds the union of all timestamps and interpolates all timeseries, resulting in full multivariate observations for each timestamp. If desired timestamps are known, those can be provided. You can also provide a function to apply to the collection of observations (such as Vector, the default is Tuple)

```
merge(t::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)
merge(f::Union{Function,Type}, t::AbstractVector{<:Real}, vts::AbstractTimeSeries...; order=0)
merge(vts::AbstractTimeSeries...; order=0)
merge(f::Union{Function,Type}, vts::AbstractTimeSeries...; order=0)

ts2 = TimeSeries([1.5, 2.6], [1.5, 2.6])
>> 2-element TimeSeries{Float64}:
    TimeRecord{Float64}(t=1970-01-01T00:00:01.500, v=1.5)
    TimeRecord{Float64}(t=1970-01-01T00:00:02.600, v=2.6)

merge(SVector, ts, ts2)
>> 7-element TimeSeries{SVector{2, Float64}}:
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:01, v=[1.0, 1.5])
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:01.500, v=[1.5, 1.5])
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:02, v=[2.0, 2.0])
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:02.600, v=[2.6, 2.6])
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:03, v=[3.0, 2.6])
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:04, v=[4.0, 2.6])
    TimeRecord{SVector{2, Float64}}(t=1970-01-01T00:00:05, v=[5.0, 2.6])



