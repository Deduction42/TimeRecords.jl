module TimeRecords
    using StaticArrays
    using Dates

    include("_TimeRecord.jl")
    include("_TimeSeries.jl")
    include("find.jl")
    include("interpolations.jl")
    include("aggregations.jl")
    include("_TimeSeriesCollector.jl")

    export AbstractTimeRecord, AbstractTimeSeries, TimeRecord, TimeInterval, TimeSeries, TimeSeriesCollector
    export interpolate, strictinterp, average, integrate, aggregate, accumulate, records
    export timestamp, timestamps, datetime, datetimes, value, values, valuetype
    export dropnan!, dropnan, mapvalues, mapvalues!, getinner, getouter, viewinner, viewouter, findinner, findouter, findbounds
    export initialhint, initialhint!, clampedbounds, keeplatest!, apply!, starttimer!
        
end
