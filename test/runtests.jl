using TimeRecords
using Test
using Revise
using StaticArrays


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
    #@test values(time_averages(ts, t, order=0))  ≈ [1.5, 1.5, 2.5]
    #@test values(time_averages(ts, t, order=1))  ≈ [1.5, 2, 3]
    @test values(time_integrals(ts, t, order=0)) ≈ [0, 1.5, 2.5]
    @test values(time_integrals(ts, t, order=1)) ≈ [0, 2, 3]

    #Test merging timeseries
    ts2 = TimeSeries([1.5, 2.6], [1.5, 2.6])
    @test values(merge(SVector, ts, ts2, order=1)) ≈ [ 
        SVector(1.0, 1.5),
        SVector(1.5, 1.5),
        SVector(2.0, 2.0),
        SVector(2.6, 2.6),
        SVector(3.0, 2.6),
        SVector(4.0, 2.6),
        SVector(5.0, 2.6),
    ]

    #Test mapvalues
    @test value.(mapvalues(sin, ts)) ≈ sin.(value.(ts))
    @test value.(mapvalues!(sin, mapvalues(Float64, ts))) ≈ sin.(value.(ts))

    #Test findinner, findouter
    dt_before = TimeInterval(-5, -2)
    dt_begin  = TimeInterval(-2, 2)
    dt_middle = TimeInterval(2, 4)
    dt_end    = TimeInterval(4, 6)
    dt_after  = TimeInterval(7, 9)

    @test findinner(ts, dt_before) == 1:0
    @test findinner(ts, dt_before+0.1) == 1:0
    @test findouter(ts, dt_before) == 1:1
    @test findouter(ts, dt_before+0.1) == 1:1

    @test findinner(ts, dt_begin)  == 1:2
    @test findinner(ts, dt_begin+0.1)  == 1:2
    @test findouter(ts, dt_begin)  == 1:2
    @test findouter(ts, dt_begin+0.1) == 1:3

    @test findinner(ts, dt_middle)  == 2:4
    @test findinner(ts, dt_middle+0.1)  == 3:4
    @test findouter(ts, dt_middle)  == 2:4
    @test findouter(ts, dt_middle+0.1) == 2:5

    @test findinner(ts, dt_end)  == 4:5
    @test findinner(ts, dt_end+0.1)  == 5:5
    @test findouter(ts, dt_end)  == 4:5
    @test findouter(ts, dt_end+0.1) == 4:5
    
    @test findinner(ts, dt_after)  == 6:5
    @test findinner(ts, dt_after+0.1)  == 6:5
    @test findouter(ts, dt_after)  == 5:5
    @test findouter(ts, dt_after+0.1) == 5:5

    @test getinner(ts, dt_middle) == ts[2:4]
    @test viewinner(ts, dt_middle) == ts[2:4]
    @test getouter(ts, dt_middle+0.1) == ts[2:5]
    @test viewouter(ts, dt_middle+0.1) == ts[2:5]



end
