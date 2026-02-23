#========================================================================================================
Episode-Builder add-on for TimeRecords
========================================================================================================#
@kwdef struct EpisodeBuilder{F1,F2,T}
    starter :: F1
    stopper :: F2
    state :: T
    start :: Base.RefValue{Float64} = Ref(NaN)
end

function build_episodes(builder::EpisodeBuilder, ts::TimeSeries)
    episodes = Pair{TimeInterval, totalizer_type(builder.state)}[]
    return add_episodes!(episodes, builder, ts)
end

function add_episodes!(episodes::AbstractVector, builder::EpisodeBuilder, ts::TimeSeries)
    for r in records(ts)
        result = isnan(builder.start[]) ? start_episode!(builder, r) : stop_episode!(builder, r)
        if !isnothing(result)
            push!(episodes, result)
        end
    end
    return episodes 
end

function start_episode!(builder::EpisodeBuilder, r::TimeRecord)
    if !isnothing(builder.starter(builder.state, r))
        builder.start[] = timestamp(r)
    end
    return nothing 
end

function stop_episode!(builder::EpisodeBuilder, r::TimeRecord)
    result = builder.stopper(builder.state, r)
    if !isnothing(result)
        Δt = TimeInterval(builder.start[], timestamp(r))
        builder.start[] = NaN 
        return Δt => result
    end
    return nothing
end

abstract type AbstractEpisodeState{S} end
totalizer_type(state::AbstractEpisodeState{S}) where S = S

@kwdef mutable struct EpisodeState{S,T} <: AbstractEpisodeState{S}
    totalizer  :: S
    lastrecord :: TimeRecord{T}
    startvalue :: T 
    stopvalue  :: T
end

function sum_above_starter(state::EpisodeState, r::TimeRecord)
    if value(r) > state.startvalue
        state.lastrecord = r 
        state.totalizer = zero(state.totalizer)
        return state
    end 
    return nothing
end

function sum_above_reducer(state::EpisodeState, r::TimeRecord)
    state.totalizer += integrate(state.lastrecord, r, order=0)
    state.lastrecord = r 
    return (value(r) < state.stopvalue) ? state.totalizer : nothing
end


#========================================================================================================
FlexUnits extension for TimeRecords
========================================================================================================#
time_dimension(x) = time_dimension(typeof(x))
time_dimension(::Type{Q}) where {U, Q <: QuantUnion{<:Any,U}} = time_dimension(U)
time_dimension(::Type{U}) where {D, U <: AbstractUnits{D}} = time_dimension(D)
time_dimension(::Type{D}) where {D <: AbstractDimensions} = D(time=1)
time_dimension(::Type{StaticDims{d}}) where {d} = StaticDims{time_dimension(d)}()
time_dimension(::Type{T}) where T = error("time_dimension not defined for type $(T)")

function TimeRecords.integrate(ts::AbstractTimeSeries{T}; order=0) where T <: QuantUnion
    q0 = 0.0*time_dimension(T)
    if isempty(ts)
        return zero(T)*q0
    end

    ∫ts = value(ts[begin])*q0
    for ii in firstindex(ts):(lastindex(ts)-1)
        ∫ts += integrate(ts[ii], ts[ii+1], order=order)
    end
    return ∫ts
end

function TimeRecords.average(ts::AbstractTimeSeries{T}, Δt::TimeInterval; indhint=nothing, order=0) where T <: QuantUnion
    dt = diff(Δt)
    if iszero(dt) #Interval is zero, simply interpolate for the average (limit when dt -> 0)
        return interpolate(ts, Δt[begin], indhint=indhint, order=order)
    else
        return integrate(ts, Δt, indhint=indhint, order=order)/(dt*time_dimension(T))
    end
end

function quant_integral(integrator, rq1::TimeRecord{<:QuantUnion}, rq2::TimeRecord{<:QuantUnion})
    (r1, r2) = map(Base.Fix1(apply2values, dstrip), (rq1, rq2))
    d = FlexUnits.equaldims(dimension(value(rq1)), dimension(value(rq2)))
    return integrator(r1, r2) * (d*time_dimension(d))
end

function TimeRecords.lastval_integral(rq1::TimeRecord{<:Quantity}, rq2::TimeRecord{<:QuantUnion})
    return quant_integral(TimeRecords.lastval_integral, rq1, rq2)
end

function TimeRecords.trapezoid_integral(rq1::TimeRecord{<:Quantity}, rq2::TimeRecord{<:QuantUnion})
    return quant_integral(TimeRecords.trapezoid_integral, rq1, rq2)
end

