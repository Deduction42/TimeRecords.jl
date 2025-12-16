module TimeRecords
    using StaticArrays
    using Dates
    using RecipesBase

    include("_TimeRecord.jl")
    include("_TimeSeries.jl")
    include("math.jl")
    include("find.jl")
    include("interpolations.jl")
    include("aggregations.jl")
    include("_TimeSeriesCollector.jl")

    export AbstractTimeRecord, AbstractTimeSeries, TimeRecord, TimeInterval, TimeSeries, RegularTimeSeries, TimeSeriesCollector
    export interpolate, strictinterp, average, integrate, aggregate, accumulate, records
    export timestamp, timestamps, datetime, datetimes, unixtime, unixtimes, value, values, valuetype
    export dropnan!, dropnan, mapvalues, mapvalues!, getinner, getouter, viewinner, viewouter, findinner, findouter, findbounds
    export initialhint, initialhint!, clampedbounds, keeplatest!, apply!
    export datetime2timestamp, timestamp2datetime
        
end
