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
TimeRecord(t::Union{Real,DateTime}, v::T) where T = TimeRecord{T}(t, v)

Base.promote_rule(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{promote_rule(R1,R2)}
Base.convert(::Type{TimeRecord{T}}, x::TimeRecord) where T = TimeRecord{T}(timestamp(x), convert(T,value(x)))
Base.promote_typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.promote_typejoin(R1,R2)}
Base.typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.typejoin(R1,R2)}

Base.show(io::IO, tr::TimeRecord{T}) where T = print(io, "TimeRecord{$(T)}(t=$(isnan(tr.t) ? missing : unix2datetime(tr.t)), v=$(tr.v))")
Base.show(io::IO, tr::TimeRecord{T}) where T<:AbstractString = print(io, "TimeRecord{$(T)}(t=$(isnan(tr.t) ? missing : unix2datetime(tr.t)), v=\"$(tr.v)\")")
Base.show(io::IO, mime::MIME"text/plain", tr::TimeRecord) = show(io, tr)

"""
Merge multiple time record with the same timestamp and apply the function "f" to the results
"""
function Base.merge(f::Union{Type,Function}, tr::TimeRecord, vtr::TimeRecord...)
    mtr = merge(tr, vtr...)
    return TimeRecord(vtr[1].t, f(value(mtr)...))
end 

"""
Merge multiple time records with the same timestamp as a tuple
"""
function Base.merge(tr::TimeRecord, vtr::TimeRecord...)
    str = (tr, vtr...)
    if !allequal(timestamp.(str))
        throw(ArgumentError("Cannot merge time records for different timestamps"))
    end
    return TimeRecord(str[begin].t, value.(str))
end


"""
Define a time interval (where the lowest value is always first), useful for integrals
"""
struct TimeInterval <: AbstractVector{Float64}
    t :: SVector{2, Float64}
    TimeInterval(x) = new(SVector{2,Float64}(_unixtime.(extrema(x))...))
end

Base.show(io::IO, Δt::TimeInterval) = print(io, "$(unix2datetime(Δt[begin])) => $(unix2datetime(Δt[end]))")
Base.show(io::IO, mime::MIME"text/plain", Δt::TimeInterval) = Base.show(io::IO, Δt)

_unixtime(t::Real) = Float64(t)
_unixtime(t::DateTime) = datetime2unix(t)
_unixtime(t::TimeRecord) = timestamp(t)

TimeInterval(t1,t2) = TimeInterval(t1=>t2)

Base.getindex(Δt::TimeInterval, ind::Colon)  = Δt.t
Base.getindex(Δt::TimeInterval, ind)  = getindex(Δt.t, ind)
Base.size(Δt::TimeInterval)           = (2,)
Base.firstindex(Δt::TimeInterval)     = 1
Base.lastindex(Δt::TimeInterval)      = 2
Base.diff(Δt::TimeInterval) = Δt.t[2] - Δt.t[1]

Base.:+(dt::TimeInterval, x::Real) = TimeInterval(dt.t .+ x)