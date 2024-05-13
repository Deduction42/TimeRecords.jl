module TimeRecords
    include(joinpath(@__DIR__, "__assembly.jl"))
    export TimeRecord, TimeInterval, TimeSeries, interpolate, time_integral
end
