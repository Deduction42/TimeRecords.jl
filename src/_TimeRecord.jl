abstract type AbstractTimeRecord{T} end

#Basic abstract functionality
valuetype(x::AbstractTimeRecord{T}) where T = T
valuetype(::Type{<:AbstractTimeRecord{T}}) where T = T

timestamp(x::AbstractTimeRecord) = x.t
value(x::AbstractTimeRecord) = x.v

datetime(x::AbstractTimeRecord) = unix2datetime(timestamp(x))
update_time(x::TR, t::Real) where TR<:AbstractTimeRecord  = TR(t, value(x))

#Enable sorting by time
Base.isless(r1::AbstractTimeRecord, r2::AbstractTimeRecord) = isless(r1.t, r2.t)

"""
A TimeRecord is a value with a timestamp; for sorting, timestamps are used
"""
struct TimeRecord{T} <: AbstractTimeRecord{T}
    t :: Float64
    v :: T
end

TimeRecord{T}(t::DateTime, v) where T = TimeRecord{T}(datetime2unix(t), v)
TimeRecord{T}(r::TimeRecord) where T = TimeRecord{T}(timestamp(r), value(r))
TimeRecord(t::Union{Real,DateTime}, v::T) where T = TimeRecord{T}(t, v)

Base.promote_rule(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{promote_rule(R1,R2)}
Base.convert(::Type{TimeRecord{T}}, x::TimeRecord) where T = TimeRecord{T}(timestamp(x), convert(T,value(x)))
Base.promote_typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.promote_typejoin(R1,R2)}
Base.typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.typejoin(R1,R2)}

Base.show(io::IO, tr::TimeRecord{T}) where T = print(io, "TimeRecord{$(T)}(t=$(isnan(tr.t) ? missing : unix2datetime(tr.t)), v=$(tr.v))")
Base.show(io::IO, tr::TimeRecord{T}) where T<:AbstractString = print(io, "TimeRecord{$(T)}(t=$(isnan(tr.t) ? missing : unix2datetime(tr.t)), v=\"$(tr.v)\")")
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
    TimeInterval(t0::T, tN::T) where T<:Union{Real,DateTime,TimeRecord} = new(_as_timestamp.(extrema((t0,tN)))...)
end
TimeInterval(tp::Pair) = TimeInterval(tp...)
Base.Pair(dt::TimeInterval) = dt.t0 => dt.tN

Base.show(io::IO, Δt::TimeInterval) = print(io, "$(unix2datetime(Δt[begin])) => $(unix2datetime(Δt[end]))")
Base.show(io::IO, mime::MIME"text/plain", Δt::TimeInterval) = Base.show(io::IO, Δt)

_as_timestamp(t::Real) = Float64(t)
_as_timestamp(t::DateTime) = datetime2unix(t)
_as_timestamp(t::TimeRecord) = timestamp(t)

Base.:+(Δt::TimeInterval, t::Real) = Δt .+ t
Base.:+(t::Real, Δt::TimeInterval) = Δt .+ t
Base.:-(Δt::TimeInterval, t::Real) = Δt .- t 
Base.:-(t::Real, Δt::TimeInterval) = t .- Δt 

Base.diff(Δt::TimeInterval) = Δt.tN - Δt.t0