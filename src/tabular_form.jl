"""
Converts a dictionary of different timeseries into a tabular dictionary form where
    - All timestamps from each timeseries is collected under the key timestamp_label=:timestamp
    - Each timeseries is interpolated according to the unified timestamp collection
"""
function tabular_form(seriesdict::AbstractDict{<:Any, TimeSeries{T}}; timestamp_label=:timestamp, order=0) where T
    timestamps = timestamp_union(seriesdict)
    tabledict  = Dict{Symbol, Vector{T}}()
    for (k, v) in pairs(seriesdict)
        tabledict[Symbol(k)] = interpolate(v, timestamps, order)
    end
    tabledict[timestamp_label] = timestamps

    return tabledict
end


"""
Returns commmon timestamps for a collection of AbstractTimeSeries
"""
function timestamp_union(seriesitr)
    tsunion = Set{Float64}()
    for tseries in values(seriesitr)
        union!(tsunion, (timestamp(tr) for tr in tseries))
    end
    return sort!(collect(tsunion)) 
end


"""
Returns commmon timestamps for a set of AbstractTimeSeries
"""
function timestamp_union(vts::AbstractTimeSeries...)
    return timestamp_union(vts)
end

# =======================================================================================
# Merging functionality through interpolation
# =======================================================================================
"""
Merges a set of timeseries to a common set of timestamps through interpolation
Produces a StaticVector for each timestamp
"""
function Base.merge(vts::AbstractTimeSeries...; order=1)
    t = timestamp_union(vts...)
    ts_interp = map(ts->interpolate(ts,t, order=order), vts)
    ts_merged = [merge(vtr...) for vtr in zip(ts_interp...)]
    return TimeSeries(ts_merged)
end


