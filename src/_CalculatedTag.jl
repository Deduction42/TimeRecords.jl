@kwdef struct CalculatedTag{F<:Function, IN<:NamedTuple} 
    name :: String
    aggregators :: IN, #NamedTuple of AggregatorSpec
    calculation :: F #function that takes only a named tuple
end

@kwdef struct Aggregator
    tag :: String 
    strategy :: Symbol
    order :: Int
    indhint :: RefValue{Int} = Ref(0)
    function Aggregator(tag, strategy, order, indhint)
        strategy in (:interpolate, :average, :integrate) || throw(ArgumentError("`strategy`` argument must be one of the following: {:interpolate, :average, :integrate}"))
        order in (0, 1) || throw(ArgumentError("`order` argument must one of the follwoing: {0, 1}"))
        return new(tag, strategy, order, indhint)
    end
end


function add_calculated_tags!(tagdict::AbstractDict{<:AbstractString, <:AbstractTimeSeries}, calc::TagCalculator; delimiter="/")
    vt = timestamp_union(tagdict[agg.name] for agg in values(calc.aggregators))

    vΔt = if length(vt) > 1
        pushfirst!(vt, vt[begin] - vt[begin+1])
        vΔt = TimeInterval.(vt[begin:(end-1)], vt[(begin+1):end])
    else
        vΔt = [TimeInterval(vt[begin], vt[begin])]
    end
    return add_calculated_tags!(tagdict, calc, vΔt, delimiter=delimiter)
end

function add_calculated_tags!(tagdict::AbstractDict{<:AbstractString, <:AbstractTimeSeries}, calc::TagCalculator, vΔt::AbstractVector{<:TimeInterval}; delimiter="/")
    calculation(Δt::TimeRecord) = TimeRecord(Δt[end], calc.calulation(_build_input(tagdict, calc.aggregators, Δt)))
    series = TimeSeries(map(calculation, vΔt))

    if valutype(series) <: NamedTuple
        for fn in fieldnames(valutype(series))
            tag = calc.name * delimiter * string(fn)
            tagdict[tag] = mapvalues(x->x[fn], series)
        end
    else 
        tagdict[calc.name] = series 
    end
    return tagdict
end
    


function _build_input(tagdict::AbstractDict{<:AbstractString, <:AbstractTimeSeries}, agg::Aggregator, Δt::TimeInterval)
    if agg.strategy == :interpolate 
        return interpolate(tagdict[agg.tag], Δt[end], order=agg.order, indhint=agg.indhint)
    elseif agg.strategy == :average
        return average(tagdict[agg.tag], Δt, order=agg.order, indhint=agg.indhint)
    elseif agg.stragety == :integrate 
        return integrate(tagdict[agg.tag], Δt, order=agg.order, indhint=agg.indhint)
    end
    throw(ArgumentError("`strategy`` argument must be one of the following: {:interpolate, :average, :integrate}"))
end

function _build_input(tagdict::AbstractDict{<:AbstractString, <:AbstractTimeSeries}, aggs::NamedTuple{FN}, Δt::TimeInterval) where FN
    return NamedTuple{FN}(map(agg-> _build_input(tagdict, agg, Δt), values(aggs))...)
end