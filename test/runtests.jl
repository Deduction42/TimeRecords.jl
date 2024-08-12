using TimeRecords
using Test

@testset "TimeRecords.jl" begin
    # Write your tests here.

    ts = TimeSeries([1,2,3,4,5],[1,2,3,4,5])
    t  = [1.5, 2.5, 3.5]

    #Test extrapolation/interpolation
    @test values(extrapolate(ts, t, order=0)) ≈ [1,2,3]
    @test values(extrapolate(ts, t, order=1)) ≈ [1.5, 2.5, 3.5]

    #Test integrals and averages
    @test values(time_averages(ts, t, order=0))  ≈ [1.5, 1.5, 2.5]
    @test values(time_averages(ts, t, order=1))  ≈ [1.5, 2, 3]
    @test values(time_integrals(ts, t, order=0)) ≈ [0, 1.5, 2.5]
    @test values(time_integrals(ts, t, order=1)) ≈ [0, 2, 3]


end
