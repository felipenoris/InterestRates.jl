
mutable struct BufferedIRCurve{M, C<:AbstractIRCurve{M}} <: AbstractIRCurve{M}
    dates_buffer::Dict{Date, Float64}
    yf_buffer::Dict{Rational, Float64}
    curve::C
    lock::Base.Threads.SpinLock
end

BufferedIRCurve(curve::AbstractIRCurve) = BufferedIRCurve(Dict{Date, Float64}(), Dict{Rational, Float64}(), curve, Base.Threads.SpinLock())

for fun in (:curve_get_name, :curve_get_daycount, :curve_get_compounding, :curve_get_method, :curve_get_date, :curve_get_dtm, :curve_get_zero_rates, :curve_get_model_parameters, :curve_get_spline_fit_on_rates, :curve_get_spline_fit_on_discount_factors)
    @eval begin
        ($fun)(curve::BufferedIRCurve) = ($fun)(curve.curve)
    end
end

curve_get_dict_parameter(curve::BufferedIRCurve, sym::Symbol) = curve_get_dict_parameter(curve.curve, sym)

function zero_rate(curve::BufferedIRCurve, maturity::Date)
    lock(curve.lock)
    try
        if !haskey(curve.dates_buffer, maturity)
            curve.dates_buffer[maturity] = _zero_rate(curve_get_method(curve), curve, maturity)
        end
        return curve.dates_buffer[maturity]
    finally
        unlock(curve.lock)
    end
end

function zero_rate(curve::BufferedIRCurve, maturity::YearFraction{T}) where {T<:Union{Integer, Rational}}
    yf_value = value(maturity)

    lock(curve.lock)
    try
        if !haskey(curve.yf_buffer, yf_value)
            curve.yf_buffer[yf_value] = _zero_rate(curve_get_method(curve), curve, maturity)
        end
        return curve.yf_buffer[yf_value]
    finally
        unlock(curve.lock)
    end
end

function zero_rate(curve::BufferedIRCurve, maturity_vec::Vector{T}) where {T<:Union{Date, YearFraction}}
    n = length(maturity_vec)
    result = Vector{Float64}(undef, n)
    for i in 1:n
        @inbounds result[i] = zero_rate(curve, maturity_vec[i])
    end
    return result
end
