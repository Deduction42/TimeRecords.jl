using TimeRecords
using Test
using StaticArrays
using Dates

@testset "TimeRecords.jl" begin
    # Test time series
    ts = TimeSeries{Float64}(1:5, 1:5)
    t  = [1.5, 2.5, 3.5]
    tse = TimeSeries{Float64}()

    #Test extrapolation/interpolation
    @test values(interpolate(ts, t, order=0)) ≈ [1, 2, 3]
    @test values(interpolate(ts, t, order=1)) ≈ [1.5, 2.5, 3.5]
    @test value(interpolate(ts, 0, order=0)) ≈ 1
    @test value(interpolate(ts, 0, order=1)) ≈ 1
    @test value(interpolate(ts, 6, order=0)) ≈ 5
    @test value(interpolate(ts, 6, order=1)) ≈ 5
    @test ismissing(value(strictinterp(ts, 6, order=0)))

    #Test integrals and averages
    @test values(average(ts, t, order=0))  ≈ [1.5, 2.5]
    @test values(average(ts, t, order=1))  ≈ [2, 3]
    @test values(integrate(ts, t, order=0)) ≈ [1.5, 2.5]
    @test values(integrate(ts, t, order=1)) ≈ [2, 3]
    @test values(accumulate(ts, order=0)) ≈ [1, 3, 6, 10]
    @test values(accumulate(ts, order=1)) ≈ [1.5, 4.0, 7.5, 12.0]

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
    

    @test keeplatest!(TimeSeries(1:5,1:5), 4) == TimeSeries(4:5, 4:5) 
    @test keeplatest!(TimeSeries(1:5,1:5), 2.5) == TimeSeries(2:5, 2:5) 
    @test keeplatest!(TimeSeries(1:5,1:5)) == TimeSeries([5],[5])
    @test keeplatest!(TimeSeries{Float64}()) == TimeSeries{Float64}()
    @test keeplatest!(TimeSeries{Float64}(), 4) == TimeSeries{Float64}()

    ts = TimeSeries{Float64}(1:5, 1:5)
    
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



    #=========================================================================
    TimeSeriesCollector tests
    =========================================================================#
    function as_tagged_series(d::Dict{String, TimeSeries{T}}) where T
        taggedrecord(tag::String, tr::TimeRecord) = TimeRecord(timestamp(tr), (k=tag, v=value(tr)))
        recordpair(tr::TimeRecord{<:NamedTuple{(:k,:v)}}) = value(tr).k => TimeRecord(timestamp(tr), value(tr).v)
    
        taggedseries = mapreduce(p->taggedrecord.(Ref(p[1]), records(p[2])), vcat, pairs(d))
        sort!(taggedseries)
    
        return recordpair.(taggedseries)
    end

    for dt in (Millisecond(0), Millisecond(1000), Millisecond(2500))
        for λt in (Millisecond(0), Millisecond(1), dt)
            display((interval=dt, delay=λt))
            t0 = DateTime(2024,1,1,0,0,0)
            t1 = DateTime(2024,1,1,0,1,0)
            vt = datetime2unix.(t0:Second(1):t1)
            dt = Millisecond(0)
            λt = Millisecond(0)

            function callback(data::Dict{String, TimeSeries{T}}, interval::TimeInterval) where T
                return getinner(data, TimeInterval(interval[1], interval[2]))
            end

            pert = rand(length(vt)).*0
            original = Dict(
                "tag1" => TimeSeries(vt .+ pert, vt),
                "tag2" => TimeSeries(vt .+ pert, vt)
            )
            dataseries = as_tagged_series(original)

            
            #Mismatch test
            collector = TimeSeriesCollector{Float64}(interval=dt, delay=λt, timer=Ref(t0+dt))
            mismatches = Tuple{Dict{String,TimeSeries{Float64}}, Dict{String,TimeSeries{Float64}}}[]

            for tagrecord in dataseries
                result = take!(collector, datetime(tagrecord[2]))
                push!(collector, tagrecord)
                if !isnothing(result)
                    y1 = getouter(result.snapshot, result.interval)
                    y0 = getouter(original, result.interval)
                    if iszero(λt) #When delay is zero, future values won't be accessible
                        for (k,v) in pairs(y0)
                            keepat!(records(v), 1:length(y1[k]))
                        end
                    end
                    
                    if y0 != y1
                        push!(mismatches, (y0, y1))
                    end
                end
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
                mismatched = (ts != original[k][1:length(ts)])
                anymismatches[] == anymismatches[] | mismatched
            end
            @test !anymismatches[]
        end
    end


end

