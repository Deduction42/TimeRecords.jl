abstract type AbstractTimeRecord{T} end

const ORIGIN_UNIX = Ref(0.0)

"""
    set_origin_date(t::DateTime)

Sets the "zero" date for TimeRecords globally. The default date is Unix Epoch. Timestamps are floats so 
precision decreases the further you are from the origin date. The default Epoch Date will allow for
milliseocond-level precision within 1000 years of Epoch. If more precision is needed, the origin date
should be shifted closer to the timestamps in question.
"""
function set_origin_date(t::DateTime)
    ORIGIN_UNIX[] = datetime2unix(t)
    return nothing 
end
timestamp2unix(t::Real) = t + ORIGIN_UNIX[]
unix2timestamp(t::Real) = t - ORIGIN_UNIX[]
datetime2timestamp(t::DateTime) = unix2timestamp(datetime2unix(t))
timestamp2datetime(t::Real) = isnan(t) ? missing : unix2datetime(timestamp2unix(t))
datetime2timestamp(t::Missing) = NaN64


#Basic abstract functionality
valuetype(x::AbstractTimeRecord{T}) where T = T
valuetype(::Type{<:AbstractTimeRecord{T}}) where T = T


value(x::AbstractTimeRecord) = x.v
datetime(x::AbstractTimeRecord) = timestamp2datetime(timestamp(x))
unixtime(x::AbstractTimeRecord) = timestamp2unix(timestamp(x))
timestamp(x::AbstractTimeRecord) = x.t

settime(x::TR, t::Real) where TR<:AbstractTimeRecord  = TR(t, value(x))

#Enable sorting by time
Base.isless(r1::AbstractTimeRecord, r2::AbstractTimeRecord) = isless(r1.t, r2.t)

"""
A TimeRecord is a value with a timestamp; for sorting, timestamps are used
"""
@kwdef struct TimeRecord{T} <: AbstractTimeRecord{T}
    t :: Float64
    v :: T
end

TimeRecord{T}(t::DateTime, v) where T = TimeRecord{T}(datetime2timestamp(t), v)
TimeRecord{T}(r::TimeRecord) where T = TimeRecord{T}(timestamp(r), value(r))
TimeRecord{T}(t::AbstractString, v) where T = TimeRecord{T}(DateTime(t), v)
TimeRecord(t, v::T) where T = TimeRecord{T}(t, v)


Base.promote_rule(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{promote_rule(R1,R2)}
Base.convert(::Type{TimeRecord{T}}, x::TimeRecord) where T = TimeRecord{T}(timestamp(x), convert(T,value(x)))
Base.promote_typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.promote_typejoin(R1,R2)}
Base.typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.typejoin(R1,R2)}

Base.show(io::IO, tr::TimeRecord{T}) where T = print(io, "TimeRecord{$(T)}(t=\"$(datetime(tr))\", v=$(value(tr)))")
Base.show(io::IO, tr::TimeRecord{T}) where T<:AbstractString = print(io, "TimeRecord{$(T)}(t=\"$(datetime(tr))\", v=\"$(value(tr))\")")
Base.show(io::IO, mime::MIME"text/plain", tr::TimeRecord) = show(io, tr)

"""
    merge(f::Union{Type,Function}, tr::TimeRecord, vtr::TimeRecord...)

Merge multiple time record with the same timestamp and apply the function "f" to the results
Useful for constructing a TimeRecord with multiple TimeRecord arguments
"""
function Base.merge(f::Union{Type,Function}, tr::TimeRecord, vtr::TimeRecord...)
    mtr = merge(tr, vtr...)
    return TimeRecord(vtr[1].t, f(value(mtr)...))
end 

"""
    merge(tr::TimeRecord, trs::TimeRecord...)

Merge multiple time records with the same timestamp as a tuple
"""
function Base.merge(tr::TimeRecord, trs::TimeRecord...)
    alltr = (tr, trs...)
    if !allequal(map(timestamp, alltr))
        throw(ArgumentError("Cannot merge time records for different timestamps"))
    end
    return TimeRecord(alltr[begin].t, map(value, alltr))
end


"""
Define a time interval (where the lowest value is always first), useful for integrals
"""
struct TimeInterval <: FieldVector{2, Float64}
    t0 :: Float64 
    tN :: Float64
    TimeInterval(t0::T, tN::T) where T = new(_as_timestamp.(extrema((t0,tN)))...)
end
TimeInterval(tp::Pair) = TimeInterval(tp...)
Base.Pair(dt::TimeInterval) = dt.t0 => dt.tN

Base.show(io::IO, Δt::TimeInterval) = print(io, "$(timestamp2datetime(Δt[begin])) => $(timestamp2datetime(Δt[end]))")
Base.show(io::IO, mime::MIME"text/plain", Δt::TimeInterval) = Base.show(io::IO, Δt)

_as_timestamp(t::Real) = Float64(t)
_as_timestamp(t::DateTime) = datetime2timestamp(t)
_as_timestamp(t::TimeRecord) = timestamp(t)
_as_timestamp(t::AbstractString) = datetime2timestamp(DateTime(t))

Base.:+(Δt::TimeInterval, t::Real) = Δt .+ t
Base.:+(t::Real, Δt::TimeInterval) = Δt .+ t
Base.:-(Δt::TimeInterval, t::Real) = Δt .- t 
Base.:-(t::Real, Δt::TimeInterval) = t .- Δt 

Base.diff(Δt::TimeInterval) = Δt.tN - Δt.t0