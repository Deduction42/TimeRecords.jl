using TimeRecords
using Test

@testset "TimeRecords.jl" begin
    # Test time series
    ts = TimeSeries([1,2,3,4,5],[1,2,3,4,5])
    t  = [1.5, 2.5, 3.5]

    #Test extrapolation/interpolation
    @test values(interpolate(ts, t, order=0)) ≈ [1, 2, 3]
    @test values(interpolate(ts, t, order=1)) ≈ [1.5, 2.5, 3.5]
    @test value(interpolate(ts, 0, order=0)) ≈ 1
    @test value(interpolate(ts, 0, order=1)) ≈ 1
    @test value(interpolate(ts, 6, order=0)) ≈ 5
    @test value(interpolate(ts, 6, order=1)) ≈ 5
    @test ismissing(value(strictinterp(ts, 6, order=0)))

    #Test integrals and averages
    @test values(time_averages(ts, t, order=0))  ≈ [1.5, 1.5, 2.5]
    @test values(time_averages(ts, t, order=1))  ≈ [1.5, 2, 3]
    @test values(time_integrals(ts, t, order=0)) ≈ [0, 1.5, 2.5]
    @test values(time_integrals(ts, t, order=1)) ≈ [0, 2, 3]

    #Test merging timeseries
    ts2 = TimeSeries([1.5, 2.6], [1.5, 2.6])
    @test values(merge(SVector, ts, ts2)) ≈ [ 
        SVector(1.0, 1.5),
        SVector(1.5, 1.5),
        SVector(2.0, 2.0),
        SVector(2.6, 2.6),
        SVector(3.0, 2.6),
        SVector(4.0, 2.6),
        SVector(5.0, 2.6),
    ]

end
