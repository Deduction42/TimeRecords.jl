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

function timestamp_union(seriesitr)
    tsunion = Set{Float64}()
    for tseries in seriesitr
        union!(tsunion, (timstamp(tr) for tr in tseries))
    end
    return sort!(collect(tsunion)) 
end

function timestamp_union(seriesdict::AbstractDict{<:Any, <:TimeSeries})
    return timestamp_union(values(seriesdict))
end