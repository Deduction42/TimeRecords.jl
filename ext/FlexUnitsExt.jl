module FlexUnitsExt 

import TimeRecords
import FlexUnits

import TimeRecords: AbstractTimeSeries, TimeRecord, TimeInterval, value, timestamp, apply2values, integrate, interpolate, average
import FlexUnits: QuantUnion, AbstractUnits, AbstractDimensions, StaticDims, dstrip, dimension

#Obtain the "seconds" unit for a given dimension type as timestamps are in seconds
seconds_unit(x) = seconds_unit(typeof(x))
seconds_unit(::Type{Q}) where {U, Q <: QuantUnion{<:Any,U}} = seconds_unit(U)
seconds_unit(::Type{U}) where {D, U <: AbstractUnits{D}} = seconds_unit(D)
seconds_unit(::Type{StaticDims{d}}) where {d} = StaticDims{seconds_unit(d)}()
seconds_unit(::Type{T}) where T = error("time_dimension not defined for type $(T)")

if pkgversion(FlexUnits) >= v"0.6.0"
    seconds_unit(::Type{D}) where {D <: AbstractDimensions} = D(s=1)
else #Old versions of flex units were not explicit
    seconds_unit(::Type{D}) where {D <: AbstractDimensions} = D(time=1)
end

#Integration and averaging require special unit-aware versions (due to timestamps being in seconds)
function TimeRecords.integrate(ts::AbstractTimeSeries{T}; order=0) where T <: QuantUnion
    q0 = 0.0*seconds_unit(T)
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
        return integrate(ts, Δt, indhint=indhint, order=order)/(dt*seconds_unit(T))
    end
end

function quant_integral(integrator, rq1::TimeRecord{<:QuantUnion}, rq2::TimeRecord{<:QuantUnion})
    (r1, r2) = map(Base.Fix1(apply2values, dstrip), (rq1, rq2))
    d = FlexUnits.equaldims(dimension(value(rq1)), dimension(value(rq2)))
    return integrator(r1, r2) * (d*seconds_unit(d))
end

function TimeRecords.lastval_integral(rq1::TimeRecord{<:QuantUnion}, rq2::TimeRecord{<:QuantUnion})
    return quant_integral(TimeRecords.lastval_integral, rq1, rq2)
end

function TimeRecords.trapezoid_integral(rq1::TimeRecord{<:QuantUnion}, rq2::TimeRecord{<:QuantUnion})
    return quant_integral(TimeRecords.trapezoid_integral, rq1, rq2)
end


end