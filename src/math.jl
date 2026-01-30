const Arithmetics = Union{Number, AbstractArray, Missing}
const OPERATORS = (:+, :-, :*, :/, :^, :div, :mod)
const MATHFUNCS = (
        :-, :inv, :sin, :cos, :tan, :sinh, :cosh, :tanh, :asin, :acos, :atan,
        :asinh, :acosh, :atanh, :sec, :csc, :cot, :asec, :acsc, :acot, :sech, :csch,
        :coth, :asech, :acsch, :acoth, :sinc, :cosc, :cosd, :cotd, :cscd, :secd,
        :sinpi, :cospi, :sind, :tand, :acosd, :atand, :acotd, :acscd, :asecd, :asind,
        :log, :log2, :log10, :log1p, :exp, :exp2, :exp10, :expm1, :frexp, :exponent, :factorial,
        :float, :abs, :real, :imag, :conj, :adjoint, :unsigned, :nextfloat, :prevfloat, :transpose, :significand
    )

function common_timestamp(arg1::TimeRecord, arg2::TimeRecord, args::TimeRecord...)
    t1 = timestamp(arg1)
    for arg in (arg2, args...) 
        timestamp(arg) == t1 || throw(ArgumentError("Timestamps must all be equal"))
    end        
    return t1
end

function common_timestamp(arg1::TimeRecord, arg2::TimeRecord)
    t1 = timestamp(arg1)
    t1 == timestamp(arg2) || throw(ArgumentError("Timestamps must be equal"))
    return t1
end

common_timestamp(arg::TimeRecord) = timestamp(arg)

function apply2values(f, arg1::TimeRecord, args::TimeRecord...)
    t = common_timestamp(arg1, args...)
    v = map(value, (arg1, args...))
    return TimeRecord(t, f(v...))
end
apply2values(f, arg::TimeRecord) = TimeRecord(timestamp(arg), f(value(arg)))

#Two-argument operations
for op in OPERATORS
    @eval Base.$op(x1::TimeRecord, x2::TimeRecord)  = apply2values($op, x1, x2)
    @eval Base.$op(x1::TimeRecord, x2::Arithmetics) = TimeRecord(timestamp(x1), $op(value(x1), x2))
    @eval Base.$op(x1::Arithmetics, x2::TimeRecord) = TimeRecord(timestamp(x2), $op(x1, value(x2)))
end

#Single-argument operations
for f in MATHFUNCS
    @eval Base.$f(x::TimeRecord) = apply2values($f, x)
end

#Timeseries operations
for op in (:+, :-)
    @eval Base.$op(x1::TimeSeries, x2::TimeSeries) = $TimeSeries($op(records(x1), records(x2)), issorted=true)
end
