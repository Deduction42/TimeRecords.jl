#========================================================================================================
Episode-Builder add-on for TimeRecords
========================================================================================================#
abstract type AbstractEpisodeState{S} end
totalizer_type(state::AbstractEpisodeState{S}) where S = S

@kwdef struct EpisodeBuilder{F1,F2,T<:AbstractEpisodeState}
    starter :: F1
    reducer :: F2
    state :: T
    start :: Base.RefValue{Float64} = Ref(NaN)
end

@kwdef mutable struct EpisodeState{S,T} <: AbstractEpisodeState{S}
    totalizer  :: S
    lastrecord :: TimeRecord{T}
    startvalue :: T 
    stopvalue  :: T
end

function build_episodes(builder::EpisodeBuilder, ts::TimeSeries)
    episodes = Pair{TimeInterval, totalizer_type(builder.state)}[]
    return add_episodes!(episodes, builder, ts)
end

function add_episodes!(episodes::AbstractVector, builder::EpisodeBuilder, ts::TimeSeries)
    for r in records(ts)
        result = isnan(builder.start[]) ? start_episode!(builder, r) : reduce_episode!(builder, r)
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

function reduce_episode!(builder::EpisodeBuilder, r::TimeRecord)
    result = builder.reducer(builder.state, r)
    if !isnothing(result)
        Δt = TimeInterval(builder.start[], timestamp(r))
        builder.start[] = NaN 
        return Δt => result
    end
    return nothing
end

function sum_above_starter(state::EpisodeState, r::TimeRecord)
    if value(r) > state.startvalue
        state.lastrecord = r 
        state.totalizer = zero(state.totalizer)
        return state.totalizer
    end 
    return nothing
end

function sum_above_reducer(state::EpisodeState, r::TimeRecord)
    state.totalizer += integrate(state.lastrecord, r, order=0)
    state.lastrecord = r 
    return (value(r) < state.stopvalue) ? state.totalizer : nothing
end
