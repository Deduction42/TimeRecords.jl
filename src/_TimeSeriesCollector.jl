#==========================================================================================

==========================================================================================#
include("tabular_form.jl")

"""
TimeSeriesCollector{T}(interval::Second, delay::Second, timer::RefValue{DateTime}, data::Dict{String, TimeSeries{T}})

Used to collect tagged time records Pair{String=>TimeRecord{T}} arriving mostly in order, designed to be taken at 'interval'
 -  'interval' is the collection interval (or window size that data will be fed to your algorithm)
        when set to zero, the interval will be the distance between timestamps
 -  'delay' is the amount of time we wait beyond the interval to collect data. 
        This helps make algorithms robust against slightly out-of-order data
 -  'timer' is a DateTime reference that indicates when the end of the next interval is due (will wait for 'delay') before collecting
 -  'data' is a Dict of TimeSeries that stores collected data. 
"""
@kwdef struct TimeSeriesCollector{T}
    interval :: Millisecond
    delay :: Millisecond
    timer :: Base.RefValue{DateTime}  = Ref(floor(now(UTC), interval))
    data  :: Dict{String, TimeSeries{T}} = Dict{String, TimeSeries{T}}()
    function TimeSeriesCollector{T}(interval, delay, timer, data) where T
        if interval < zero(interval)
            error("interval must be non-negative")
        elseif delay < zero(delay)
            error("delay must be non-negative")
        else
            return new{T}(interval, delay, timer, data)
        end
    end
end

TimeSeriesCollector(interval, delay, timer, data::AbstractDict{<:AbstractString, TimeSeries{T}}) where T = TimeSeriesCollector{T}(interval, delay, timer, data)

"""
apply!(f::Function, collector::TimeSeriesCollector, tagrecord::Pair{<:String, <:TimeRecord}) :: Union{Nothing, Task}

Use apply!(collector, timestamp(tagrecord[2])) :: Union{Nothing, NamedTuple{snapshot<:Dict, interval::TimeInterval}}
 -  If data is returned (i.e. not 'nothing') collector.data before collector.timer[] will be deleted
 -  The function 'f' will be applied to 'data.snapshot, data.interval' in a separate 'Task' which is returned
Regardless of the outcome of 'apply', 'tagrecord' will be appended to collector.data

Notes:
 -  The function f must accept two arguments: (data::Dict{String,<:TimeSereis}, interval::TimeInterval)
 -  'interval' will be contained inside 'data' allowing for any desired interpolation scheme
"""
function apply!(f::Function, collector::TimeSeriesCollector, tagrecord::Pair{<:String, <:TimeRecord})
    data = apply!(collector, tagrecord)
    if isnothing(data)
        return nothing
    else
        return Threads.@spawn f(data.snapshot, data.interval)
    end
end

"""
apply!(f::Function, collector::TimeSeriesCollector, t::DateTime) :: Union{Nothing, Task}

Uses take!(collector, t) :: Union{Nothing, NamedTuple{snapshot<:Dict, interval::TimeInterval}}
 -  If data is returned (i.e. not 'nothing') collector.data before collector.timer[] will be deleted
 -  The function 'f' will be applied to 'data.snapshot, data.interval' in a separate 'Task' which is returned

Notes:
 -  The function f must accept two arguments: (data::Dict{String,<:TimeSereis}, interval::TimeInterval)
 -  'interval' will be contained inside 'data' allowing for any desired interpolation scheme
"""

function apply!(f::Function, collector::TimeSeriesCollector, t::DateTime)
    data = take!(collector, t)
    if isnothing(data)
        return nothing
    else
        return Threads.@spawn f(data.snapshot, data.interval)
    end
end



"""
apply!(collector::TimeSeriesCollector, tagrecord::Pair{<:String, <:TimeRecord}) :: Union{Nothing, NamedTuple{snapshot<:Dict, interval::TimeInterval}}

Use 'take!(collector, timestamp(tagrecord[2]))' which returns 'Union{Nothing, NamedTuple{snapshot<:Dict, interval::TimeInterval}}'
 -  If data is returned (i.e. not 'nothing') collector.data before collector.timer[] will be deleted
Regardless of the outcome of 'take', 'tagrecord' will be appended to collector.data

Notes:
 -  'interval' will be contained inside 'data' allowing for any desired interpolation scheme
"""
function apply!(collector::TimeSeriesCollector, tagrecord::Pair{<:String, <:TimeRecord})
    result = take!(collector, datetime(tagrecord[2]))
    push!(collector, tagrecord)
    return result
end


"""
take!(collector::TimeSeriesCollector, t::DateTime) :: Union{Nothing, @NamedTuple{snapshot::Dict{String,TimeSeries}, interval::TimeInterval}}

If t is greater than the timer and delay, 
(1) Return a copy (snapshot) of the data, and the time interval 
(2) Delete data earlier than the latest point before the time interval
Otherwise, no action is taken and 'nothing' is returned

Notes:
 -  'interval' will be contained inside 'snapshot' allowing for any desired interpolation scheme
 -  'snapshot' and 'interval' can span more than one 'collector.interval' if many intervals have elapsed between samples
"""
function Base.take!(collector::TimeSeriesCollector, t::DateTime)
    if t > (collector.timer[] + collector.delay + collector.interval)
        #Construct the time interval
        t0 = collector.timer[] #Start of this interval
        t1 = next_interval_start(collector, t)
        interval = TimeInterval(t0, t1)

        #Set the start time of the new interval
        collector.timer[] = t1

        #Collect data that spans the time interval
        snapshot = getouter(collector.data, interval)

        #Delete unneeded data
        for v in values(collector.data)
            keeplatest!(v, t1)
        end
        return (snapshot=snapshot, interval=interval)
    else
        return nothing
    end
end

function getouter(data::Dict{String,<:AbstractTimeSeries{T}}, Δt::TimeInterval) where T 
    return Dict{String, TimeSeries{T}}( k=>getouter(v,Δt) for (k,v) in pairs(data) )
end

function getinner(data::Dict{String,<:AbstractTimeSeries{T}}, Δt::TimeInterval) where T 
    return Dict{String, TimeSeries{T}}( k=>getinner(v,Δt) for (k,v) in pairs(data) )
end


function Base.push!(collector::TimeSeriesCollector{T}, tagrecord::Pair{<:AbstractString, <:TimeRecord}; warn_mismatch=false) where T
    (tag, rec) = tagrecord
    ts = get!(collector.data, tag) do
        if warn_mismatch
            @warn "Following tag '"*tag*"' does not exist in registry, creating new series"
        end
        TimeSeries{T}(TimeRecord{T}[])
    end
    push!(ts, rec)
    return collector
end

"""
calctimer(collector::TimeSeriesCollector, current::DateTime)

Calculates the beginning of the next time interval given the current time
"""
function next_interval_start(collector::TimeSeriesCollector, current::DateTime)
    rawstart = current - collector.delay - collector.interval
    newstart = iszero(collector.interval) ? rawstart : floor(rawstart, collector.interval)
    return max(collector.timer[], newstart)
end




