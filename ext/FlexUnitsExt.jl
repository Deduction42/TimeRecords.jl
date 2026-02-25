module FlexUnitsExt 

import TimeRecords
import FlexUnits

import TimeRecords: AbstractTimeSeries, TimeRecord, TimeInterval, value, timestamp, apply2values, integrate, interpolate, average
import FlexUnits: QuantUnion, AbstractUnits, AbstractDimensions, StaticDims, dstrip, dimension

#Time dimension is a special unit with unique pertinence to TimeRecords
time_dimension(x) = time_dimension(typeof(x))
time_dimension(::Type{Q}) where {U, Q <: QuantUnion{<:Any,U}} = time_dimension(U)
time_dimension(::Type{U}) where {D, U <: AbstractUnits{D}} = time_dimension(D)
time_dimension(::Type{D}) where {D <: AbstractDimensions} = D(time=1)
time_dimension(::Type{StaticDims{d}}) where {d} = StaticDims{time_dimension(d)}()
time_dimension(::Type{T}) where T = error("time_dimension not defined for type $(T)")

#Integration and averaging require special unit-aware versions (due to timestamps being in seconds)
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

function TimeRecords.lastval_integral(rq1::TimeRecord{<:QuantUnion}, rq2::TimeRecord{<:QuantUnion})
    return quant_integral(TimeRecords.lastval_integral, rq1, rq2)
end

function TimeRecords.trapezoid_integral(rq1::TimeRecord{<:QuantUnion}, rq2::TimeRecord{<:QuantUnion})
    return quant_integral(TimeRecords.trapezoid_integral, rq1, rq2)
end


end