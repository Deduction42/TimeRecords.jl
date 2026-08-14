@kwdef struct CalculatedTag{F<:Function, IN<:NamedTuple} 
    name :: String
    aggregators :: IN #NamedTuple of AggregatorSpec
    calculation :: F #function that takes only a named tuple
end

@kwdef struct Aggregator
    tag :: String 
    strategy :: Symbol = :interpolate
    order :: Int = 0
    indhint :: Base.RefValue{Int} = Ref(1)
    function Aggregator(tag, strategy, order, indhint)
        strategy in (:interpolate, :average, :integrate) || throw(ArgumentError("`strategy`` argument must be one of the following: {:interpolate, :average, :integrate}"))
        order in (0, 1) || throw(ArgumentError("`order` argument must one of the follwoing: {0, 1}"))
        return new(tag, strategy, order, indhint)
    end
end

function add_calculated_tags(tagsdict, calcs::Tuple; delimiter="/") 
    newdict = copy(tagsdict)
    add_calculated_tags!(newdict, calcs::Tuple; delimiter=delimiter)
    return newdict 
end

function add_calculated_tags(tagsdict, calcs::Tuple, vt::AbstractVector; delimiter="/")
    newdict = copy(tagsdict)
    add_calculated_tags!(newdict, calcs::Tuple, vt; delimiter=delimiter)
    return newdict 
end

function add_calculated_tags!(tagdict, calcs::Tuple; delimiter="/")
    for calc in calcs
        add_calculated_tags!(tagdict, calc, delimiter=delimiter)
    end
    return nothing
end

function add_calculated_tags!(tagdict, calcs::Tuple, vt::AbstractVector; delimiter="/")
    for calc in calcs
        add_calculated_tags!(tagdict, calc, vt, delimiter=delimiter)
    end
    return nothing
end

function add_calculated_tags!(tagdict, calc::CalculatedTag; delimiter="/")
    vt = timestamp_union(map(agg-> tagdict[agg.tag], values(calc.aggregators))...)
    return _add_calculated_tags!(tagdict, calc, vt, delimiter)
end

function add_calculated_tags!(tagdict, calc::CalculatedTag, vt::AbstractVector{<:Real}; delimiter="/")
    return _add_calculated_tags!(tagdict, calc, vt, delimiter)
end

function add_calculated_tags!(tagdict, calc::CalculatedTag, vΔt::AbstractVector{<:TimeInterval}; delimiter="/")
    return _add_calculated_tags!(tagdict, calc, vΔt, delimiter)
end 

function _add_calculated_tags!(tagdict, calc::CalculatedTag, vt::AbstractVector{<:Real}, delimiter::AbstractString)
    vΔt = _build_intervals(vt)
    return _add_calculated_tags!(tagdict, calc, vΔt, delimiter)
end

function _add_calculated_tags!(tagdict, calc::CalculatedTag, vΔt::AbstractVector{<:TimeInterval}, delimiter::AbstractString)
    calculation(Δt::TimeInterval) = TimeRecord(Δt[end], calc.calculation(_build_input(tagdict, calc.aggregators, Δt)))
    series = TimeSeries(map(calculation, vΔt))

    if valuetype(series) <: NamedTuple
        for fn in fieldnames(valuetype(series))
            tag = calc.name * delimiter * string(fn)
            tagdict[tag] = mapvalues(x->x[fn], series)
        end
    else 
        tagdict[calc.name] = series 
    end
    return nothing
end

function _build_input(tagdict, aggs::NamedTuple{FN}, Δt::TimeInterval) where FN
    return NamedTuple{FN}(map(agg-> _build_input(tagdict, agg, Δt), values(aggs)))
end

function _build_input(tagdict, agg::Aggregator, Δt::TimeInterval)
    if agg.strategy == :interpolate 
        return interpolate(tagdict[agg.tag], Δt[end], order=agg.order, indhint=agg.indhint)
    elseif agg.strategy == :average
        return average(tagdict[agg.tag], Δt, order=agg.order, indhint=agg.indhint)
    elseif agg.strategy == :integrate 
        return integrate(tagdict[agg.tag], Δt, order=agg.order, indhint=agg.indhint)
    end
    throw(ArgumentError("`strategy`` argument must be one of the following: {:interpolate, :average, :integrate}"))
end

function _build_intervals(vt::AbstractVector{<:Real})
    if length(vt) > 1
        vΔt = TimeInterval.(vt[begin:(end-1)], vt[(begin+1):end])
        pushfirst!(vΔt, TimeInterval(2*vt[begin]-vt[begin+1], vt[begin]))
        return vΔt
    else
        return [TimeInterval(vt[begin], vt[begin])]
    end
end

function _build_intervals(vt::AbstractRange{<:Real})
    return TimeInterval.(vt .- step(vt),  vt)
end