using TimeRecords
using Test
using StaticArrays
using Dates
using TestItems: @testitem
using TestItemRunner
using Plots
using Aqua 

#====================================================================================================================================
Run these commands at startup to see coverage
julia --startup-file=no --depwarn=yes --threads=auto -e 'using Coverage; clean_folder(\"src\"); clean_folder(\"test\")'
julia --startup-file=no --depwarn=yes --threads=auto --code-coverage=user --project=. -e 'using Pkg; Pkg.test(coverage=true)'
julia --startup-file=no --depwarn=yes --threads=auto coverage.jl
====================================================================================================================================#
@testset "TimeRecord basics" begin
    @test TimeRecords.valuetype(TimeRecord(0,2.0+im)) == ComplexF64
    @test TimeRecords.valuetype(TimeRecord{Int64}) == Int64
    @test TimeRecords.update_time(TimeRecord(0,1), 1) == TimeRecord(1,1)
    @test promote(TimeRecord(0,1), TimeRecord(0,1.0)) === (TimeRecord(0,1.0), TimeRecord(0,1.0))  
    @test [TimeRecord(0,1), TimeRecord(0,missing)] isa Vector{TimeRecord{Union{Missing, Int64}}}
    @test Base.promote_typejoin(TimeRecord{Float64}, TimeRecord{Nothing}) == TimeRecord{Base.promote_typejoin(Float64, Nothing)}
    @test typejoin(TimeRecord{Float64}, TimeRecord{Nothing}) == TimeRecord{typejoin(Float64, Nothing)}
    @test string(TimeRecord(0,1)) == "TimeRecord{Int64}(t=1970-01-01T00:00:00, v=1)"
    @test string(TimeRecord(0,"this")) == "TimeRecord{String}(t=1970-01-01T00:00:00, v=\"this\")"
    @test merge(TimeRecord(0,1), TimeRecord(0,2)) == TimeRecord(0, (1,2))
    @test merge(SVector, TimeRecord(0,1), TimeRecord(0,2)) == TimeRecord(0, SVector(1,2))
    @test_throws ArgumentError merge(TimeRecord(0,1), TimeRecord(1,1))

    @test string(TimeInterval(0,1)) == "1970-01-01T00:00:00 => 1970-01-01T00:00:01"
    @test firstindex(TimeInterval(0,1)) == 1
    @test lastindex(TimeInterval(0,1)) == 2
    @test TimeInterval(0,1)[:] == SVector(0,1)
    @test size(TimeInterval(0,1)) == (2,)

end


@testset "TimeSeries basics" begin
    # Test time series
    ts = TimeSeries{Float64}(1:5, 1:5)
    t  = [1.5, 2.5, 3.5]

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

    #Test merging timeseries to defined time records
    vt = [0,1,3,5]
    @test values(merge(SVector, vt, ts, ts2, ts2, order=0)) ≈ [
        SVector(1.0, 1.5, 1.5),
        SVector(1.0, 1.5, 1.5),
        SVector(3.0, 2.6, 2.6),
        SVector(5.0, 2.6, 2.6)
    ]

    #Test merging without constructors
    ts2 = TimeSeries([1.5, 2.6], [1.5, 2.6])
    @test values(merge(vt, ts, ts2, order=0)) == [ 
        (1.0, 1.5),
        (1.0, 1.5),
        (3.0, 2.6),
        (5.0, 2.6)
    ]
    @test values(merge(ts, ts2, order=0)) == [
        (1.0, 1.5),
        (1.0, 1.5),
        (2.0, 1.5),
        (2.0, 2.6),
        (3.0, 2.6),
        (4.0, 2.6),
        (5.0, 2.6)
    ]

    #Test mapvalues
    @test value.(mapvalues(sin, ts)) ≈ sin.(value.(ts))
    @test value.(mapvalues!(sin, mapvalues(Float64, ts))) ≈ sin.(value.(ts))
    
    #Test keeplatest
    @test keeplatest!(TimeSeries(1:5,1:5), 4) == TimeSeries(4:5, 4:5) 
    @test keeplatest!(TimeSeries(1:5,1:5), 2.5) == TimeSeries(2:5, 2:5) 
    @test keeplatest!(TimeSeries(1:5,1:5)) == TimeSeries([5],[5])
    @test keeplatest!(TimeSeries{Float64}()) == TimeSeries{Float64}()
    @test keeplatest!(TimeSeries{Float64}(), 4) == TimeSeries{Float64}()

    ts = TimeSeries{Float64}(1:5, 1:5)
    
    #Test various operations
    @test timestamps(ts) == 1:5
    @test datetimes(ts)  == unix2datetime.(1:5)
    @test values(ts) == 1:5
    @test eltype(ts) == TimeRecord{Float64}
    @test eltype(TimeSeries{ComplexF64}) == TimeRecord{ComplexF64}
    @test valuetype(ts) == Float64
    @test valuetype(TimeSeries{ComplexF64}) == ComplexF64
    @test Vector(ts) == ts.records
    @test ts[1:3] == TimeSeries{Float64}(1:3,1:3)
    @test ts[[2,1,3]] == ts[1:3]
    @test ts[:] == TimeSeries{Float64}(1:5,1:5)
    @test ts[BitVector([1,1,1,0,0])] == TimeSeries{Float64}(1:3,1:3)
    @test ts[TimeInterval(2:4)] == TimeSeries{Float64}(2:4,2:4)
    @test ts[TimeInterval(1.5,4.5)] == TimeSeries{Float64}(2:4,2:4)
    @test keepat!(deepcopy(ts), 2:3) == ts[2:3]
    @test deleteat!(deepcopy(ts), 4:5) == ts[1:3]
    @test push!(deepcopy(ts), TimeRecord(0,0)) == TimeSeries{Float64}(0:5,0:5)
    @test push!(deepcopy(ts), TimeRecord(6,6)) == TimeSeries{Float64}(1:6,1:6)
    @test push!(deepcopy(ts), TimeRecord(1.5,1.5)) == TimeSeries{Float64}([1;1.5;2:5], [1;1.5;2:5])
    @test dropnan(TimeSeries{Float64}([1,2],[1,NaN])) == TimeSeries{Float64}([1],[1])
    @test TimeInterval(ts) == TimeInterval(1,5)
    @test_throws ArgumentError view(ts, [1,2,3])

    ts_view = TimeRecords.TimeSeriesView(view(ts.records, 1:3))
    @test view(ts, 1:3) == ts_view
    @test view(ts, TimeInterval(1,3)) == ts_view
    @test view(ts, BitVector([1,1,1,0,0])) == ts_view

    ts1 = setindex!(deepcopy(ts), TimeRecord(1, NaN), 1)
    @test ts1 == TimeSeries(1:5, [NaN;2:5])

    #Various constructors and indexing
    ts[1:3] .= 0
    @test ts == TimeSeries{Float64}(1:5, [0,0,0,4,5])
    
    ts[1:3] = 1:3
    @test ts == TimeSeries{Float64}(1:5, 1:5)

    ts[1:3] = TimeSeries(1:3,1:3)
    @test ts == TimeSeries{Float64}(1:5, 1:5)

    ts[2] = TimeRecord(2.5,2)
    @test ts == TimeSeries{Float64}([1,2.5,3,4,5], 1:5)

    ts[2] = TimeRecord(2,2)
    @test ts == TimeSeries{Float64}(1:5, 1:5)

    ts[2] = TimeRecord(3.5,2)
    @test ts == TimeSeries{Float64}([1,3,3.5,4,5], [1,3,2,4,5])

    ts[3] = TimeRecord(2,2)
    @test ts == TimeSeries{Float64}(1:5,1:5)

    ts[1:3] = TimeSeries(2:4, 1:3)
    @test ts == TimeSeries{Float64}([2:4;4:5],1:5)

    interval = TimeInterval(DateTime("2024-01-01T00:00:48.928"),DateTime("2024-01-01T00:00:49.115"))
    dates = [DateTime("2024-01-01T00:00:48.393"), DateTime("2024-01-01T00:00:49.275"), DateTime("2024-01-01T00:00:50.470")]
    ts = TimeSeries(dates, 1:3)
    @test getouter(ts, interval) == ts[1:2]

    @test plot(ts) isa Plots.Plot
    @test plot(ts, use_dates=false) isa Plots.Plot
    jan_hours = 0:3600:(24*3600*31)
    @test plot(TimeSeries(jan_hours, jan_hours)) isa Plots.Plot
end

@testset "TimeSeries find" begin
    ts = TimeSeries{Float64}(1:5, 1:5)
    tse = TimeSeries{Float64}()

    #Test findinner, findouter
    dt_before = TimeInterval(-5, -2)
    dt_begin  = TimeInterval(-2, 2)
    dt_middle = TimeInterval(2, 4)
    dt_end    = TimeInterval(4, 6)
    dt_after  = TimeInterval(7, 9)
    dt_between = TimeInterval(2.1, 2.2)

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

    @test findinner(ts, dt_between) == 3:2
    @test findouter(ts, dt_between) == 2:3

    @test getinner(ts, dt_middle) == ts[2:4]
    @test viewinner(ts, dt_middle) == ts[2:4]
    @test getouter(ts, dt_middle+0.1) == ts[2:5]
    @test viewouter(ts, dt_middle+0.1) == ts[2:5]

    @test findinner(tse, dt_middle) == 1:0
    @test findouter(tse, dt_middle) == 1:0
    @test getinner(tse, dt_middle)  == tse[1:0]
    @test getouter(tse, dt_middle)  == tse[1:0]

    @test findinner(ts, dt_between, Ref(1)) == 3:2
    @test findouter(ts, dt_between, Ref(1)) == 2:3

    @test TimeRecords.initialhint!(nothing, ts, 1.5)[] == 1
    @test TimeRecords.initialhint!(2, ts, 1.5)[] == 1


end

@testset "Interpolation/Aggregation" begin
    # Test time series
    ts = TimeSeries{Float64}(1:5, 1:5)
    t  = [1.5, 2.5, 3.5]

    #Test indhint initialization
    @test initialhint!(Ref(1), ts, 2.5)[] ≈ 2
    @test initialhint!(Ref(1), ts, 0.5)[] ≈ 1

    #Test nearest interpolation (missings are not possible)
    @test interpolate(ts, t, order=0) ≈ [1, 2, 3]
    @test interpolate(ts, t, order=1) ≈ [1.5, 2.5, 3.5]
    @test interpolate(ts, 0, order=0) ≈ 1
    @test interpolate(ts, 0, order=1) ≈ 1
    @test interpolate(ts, 6, order=0) ≈ 5
    @test interpolate(ts, 6, order=1) ≈ 5

    #Testing strict versions of interpolation (missings are possible)
    missing_equal(v1::Missing, v2::Missing) = true
    missing_equal(v1, v2) = (v1==v2)
    @test mapreduce(missing_equal, &, strictinterp(ts, [0,2,3], order=0), [missing, 2.0, 3.0])
    @test mapreduce(missing_equal, &, strictinterp(ts, [0,2,3], order=1), [missing, 2.0, 3.0])
    @test strictinterp(ts, t, order=0) ≈ [1, 2, 3]
    @test strictinterp(ts, t, order=1) ≈ [1.5, 2.5, 3.5]
    @test ismissing(strictinterp(ts, 6, order=0))
    @test ismissing(strictinterp(ts, 6, order=1))

    #Test errors for invalid orders
    @test_throws ArgumentError interpolate(ts, 2.5, order=3)
    @test_throws ArgumentError interpolate(ts, [2.5,3.5], order=3)
    @test_throws ArgumentError interpolate(ts[1], ts[2], 2.5, order=3)
    @test_throws ArgumentError strictinterp(ts, 2.5, order=3)
    @test_throws ArgumentError strictinterp(ts, [2.5,3.5], order=3)

    #Test aggregations
    @test average(ts, t, order=0)  ≈ [1.5, 2.5]
    @test average(ts, t, order=1)  ≈ [2, 3]
    @test integrate(ts, t, order=0) ≈ [1.5, 2.5]
    @test integrate(ts, t, order=1) ≈ [2, 3]
    @test accumulate(ts, order=0) ≈ [1, 3, 6, 10]
    @test accumulate(ts, order=1) ≈ [1.5, 4.0, 7.5, 12.0]
    @test integrate(ts, TimeInterval(1.1, 1.3), order=0) ≈ 0.2
    @test average(ts, TimeInterval(1.1, 1.3), order=0) ≈ 1.0
    @test integrate(ts, TimeInterval(1.1, 1.3), order=1) ≈ 0.24
    @test average(ts, TimeInterval(1.1, 1.3), order=1) ≈ 1.2
    @test_throws ArgumentError integrate(ts, TimeInterval(1.1, 1.3), order=3)
    @test_throws ArgumentError integrate(ts[1], ts[2], order=3)
    @test integrate(ts, TimeInterval(1.1, 1.1), order=1) ≈ 0.0
    @test integrate(ts, TimeInterval(1.1, 1.1), order=0) ≈ 0.0
    @test integrate(ts[1:0]) ≈ 0.0

    @test (@test_logs (:warn, "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate") integrate(ts, TimeInterval(-2,-1), order=0)) == 1.0
    @test (@test_logs (:warn, "Time interval (Δt) occurs completely before the timeseries history, results are likely inaccurate") integrate(ts, TimeInterval(-2,-1), order=1)) == 1.0
    @test (@test_logs (:warn, "Time interval (Δt) occurs completely after the timeseries history, results are likely inaccurate") integrate(ts, TimeInterval(8,9), order=1)) == 5.0
    @test (@test_nowarn integrate(ts, TimeInterval(8,9), order=0)) == 5.0
    
    @test average(ts, TimeInterval(1,2), order=0) ≈ 1
    @test average(ts, TimeInterval(1,2), order=1) ≈ 1.5
    @test average(ts, TimeInterval(2,2), order=0) ≈ 2
    @test average(ts, TimeInterval(2.5,2.5), order=1) ≈ 2.5
    @test average(ts, TimeInterval(2.5,2.5), order=0) ≈ 2

    @test max(ts, TimeInterval(4,5)) == 5
    @test max(ts, TimeInterval(4.1, 4.2)) == 4
    @test min(ts, TimeInterval(4,5)) == 4
    @test min(ts, TimeInterval(4.1,4.2)) == 4
    @test max(ts, 3:5) == [4,5]
    @test min(ts, 3:5) == [3,4]


end    

@testset "TimeSeriesCollector" begin
    function as_tagged_series(d::Dict{String, TimeSeries{T}}) where T
        taggedrecord(tag::String, tr::TimeRecord) = TimeRecord(timestamp(tr), (k=tag, v=value(tr)))
        recordpair(tr::TimeRecord{<:NamedTuple{(:k,:v)}}) = value(tr).k => TimeRecord(timestamp(tr), value(tr).v)
    
        taggedseries = mapreduce(p->taggedrecord.(Ref(p[1]), records(p[2])), vcat, pairs(d))
        sort!(taggedseries)
    
        return recordpair.(taggedseries)
    end

    function callback(data::Dict{String, TimeSeries{T}}, interval::TimeInterval) where T
        return getinner(data, TimeInterval(interval[1], interval[2]-1e-6))
    end

    #=========================================================================
    Testing for various intervals
    =========================================================================#
    for dt in (Millisecond(0), Millisecond(1000), Millisecond(2500))
        for λt in (Millisecond(0), Millisecond(1), dt)
            #dt = Millisecond(0)
            #λt = Millisecond(1)
            #display((interval=dt, delay=λt))

            t0 = DateTime(2024,1,1,0,0,0)
            t1 = DateTime(2024,1,1,0,1,0)
            vt = datetime2unix.(t0:Second(1):t1)
            

            pert = rand(length(vt)).*0
            original = Dict(
                "tag1" => TimeSeries(vt .+ pert, vt),
                "tag2" => TimeSeries(vt .+ pert, vt)
            )
            dataseries = as_tagged_series(original)

            
            #Mismatch test
            collector  = TimeSeriesCollector{Float64}(interval=dt, delay=λt, timer=Ref(t0))
            mismatches = Tuple{Dict{String,TimeSeries{Float64}}, Dict{String,TimeSeries{Float64}}}[]

            for tagrecord in dataseries
                result = take!(collector, datetime(tagrecord[2]))
                push!(collector, tagrecord)
                if !isnothing(result)
                    y1 = getouter(result.snapshot, result.interval)
                    y0 = getouter(original, result.interval)
                    if λt < Second(1) #When delay is less than input sampling rate, future values won't be accessible
                        for (k,v) in pairs(y0)
                            keepat!(records(v), 1:length(y1[k]))
                        end
                    end
                    
                    if y0 != y1
                        push!(mismatches, (y0, y1))
                    end
                end
            end
            if !isempty(mismatches)
                @warn "Test failed at $((interval=dt, delay=λt))"
            end
            @test isempty(mismatches)

            #Reconstruction test
            collector = TimeSeriesCollector{Float64}(interval=dt, delay=λt, timer=Ref(t0+dt))
            reconstructed = Dict{String, TimeSeries{Float64}}()
            for tagrecord in dataseries
                result = apply!(callback, collector, tagrecord)
                if !isnothing(result)
                    data = fetch(result)
                    for (k,v) in pairs(data)
                        ts = get!(reconstructed, k) do 
                            TimeSeries{Float64}()
                        end
                        append!(records(ts), v)
                    end
                end
            end

            anymismatches = Ref(false)
            for (k, ts) in pairs(reconstructed)
                n = min(length(original[k]), length(ts))
                mismatched = (ts != original[k][1:n])
                anymismatches[] == anymismatches[] | mismatched
            end
            if anymismatches[]
                @info "Test failed at $((interval=dt, delay=λt))"
            end
            @test !anymismatches[]
        end
    end

    #=========================================================================
    Basic tests
    =========================================================================#
    t0 = DateTime(2024,1,1,0,0,0)
    t1 = DateTime(2024,1,1,0,1,0)
    vt = datetime2unix.(t0:Second(1):t1)
    original = Dict(
        "tag1" => TimeSeries(vt, vt),
        "tag2" => TimeSeries(vt, vt)
    )
    inputseries = as_tagged_series(original)

    #Constructor errors
    @test_throws ArgumentError("interval must be non-negative") TimeSeriesCollector{Float64}(interval=-Second(1), delay=Second(10), timer=Ref(t0))
    @test_throws ArgumentError("delay must be non-negative") TimeSeriesCollector{Float64}(interval=Second(1), delay=-Second(10), timer=Ref(t0))
    @test TimeSeriesCollector(interval=Second(1), delay=Second(1), timer=Ref(t0), data=original) isa TimeSeriesCollector{Float64}

    #Initial collector
    collector  = TimeSeriesCollector{Float64}(interval=Second(1), delay=Second(2), timer=Ref(t0))
    tag = inputseries[1][1]

    #Test warnings for pushes
    @test_logs (:warn, "Following tag '"*tag*"' does not exist in registry, creating new series") push!(collector, inputseries[1], warn_mismatch=true)
    @test_nowarn push!(collector, inputseries[2])

    #Simple callback function
    function simple_callback(data::AbstractDict{<:AbstractString, <:AbstractTimeSeries}, Δt::TimeInterval)
        v1 = interpolate(data["tag1"], Δt[end], order=0)
        v2 = interpolate(data["tag2"], Δt[end], order=0)
        return v1 + v2
    end

    #Returns nothing before the execution time
    @test isnothing(apply!(simple_callback, collector, t0))
    @test fetch(apply!(simple_callback, deepcopy(collector), t0 + Second(5))) ≈ 3.4081344e9

end

@testset "Aqua.jl" begin
    Aqua.test_all(TimeRecords)
end