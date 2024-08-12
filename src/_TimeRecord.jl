abstract type AbstractTimeRecord{T} end

#Basic abstract functionality
recordtype(x::AbstractTimeRecord{T}) where T = T
recordtype(::Type{<:AbstractTimeRecord{T}}) where T = T

timestamp(x::AbstractTimeRecord) = x.t
value(x::AbstractTimeRecord) = x.v

unixtime(x::AbstractTimeRecord) = x.t
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

TimeRecord(t::Real, v::T) where T = TimeRecord{T}(t, v)

Base.:+(Δt::TimeRecord, x::Real) = TimeRecord(Δt.t, Δt.v+x)
Base.:-(Δt::TimeRecord, x::Real) = TimeRecord(Δt.t, Δt.v-x)
Base.:*(Δt::TimeRecord, x::Real) = TimeRecord(Δt.t, Δt.v*x)
Base.:/(Δt::TimeRecord, x::Real) = TimeRecord(Δt.t, Δt.v/x)
Base.promote_rule(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{promote_rule(R1,R2)}
Base.convert(::Type{TimeRecord{T}}, x::TimeRecord) where T = TimeRecord{T}(timestamp(x), convert(T,value(x)))
Base.promote_typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.promote_typejoin(R1,R2)}
Base.typejoin(T1::Type{TimeRecord{R1}}, T2::Type{TimeRecord{R2}}) where {R1,R2} = TimeRecord{Base.typejoin(R1,R2)}

"""
Merge multiple time record with the same timestamp and apply the function "f" to the results
"""
function Base.merge(f::Union{Type,Function}, vtr::TimeRecord...)
    mtr = merge(vtr...)
    return TimeRecord(vtr[1].t, f(value(mtr)...))
end 

"""
Merge multiple time records with the same timestamp as a tuple
"""
function Base.merge(vtr::TimeRecord...)
    if !mapreduce(timestamp, isequal, vtr)
        error("Cannot merge time records for different timestamps")
    end
    return TimeRecord(vtr[begin].t, value.(vtr))
end


"""
Define a time interval (where the lowest value is always first), useful for integrals
"""
struct TimeInterval <: AbstractVector{Float64}
    t :: SVector{2, Float64}
    TimeInterval(x) = new(SVector{2,Float64}(extrema(x)...))
end

TimeInterval(t1::Real, t2::Real) = TimeInterval((t1,t2))
TimeInterval(r1::AbstractTimeRecord, r2::AbstractTimeRecord) = TimeInterval(timestamp(r1), timestamp(r2))


Base.getindex(Δt::TimeInterval, ind::Colon)  = Δt.t
Base.getindex(Δt::TimeInterval, ind)  = getindex(Δt.t, ind)
Base.size(Δt::TimeInterval)           = (2,)
Base.firstindex(Δt::TimeInterval)     = 1
Base.lastindex(Δt::TimeInterval)      = 2
Base.diff(Δt::TimeInterval) = Δt.t[2] - Δt.t[1]

