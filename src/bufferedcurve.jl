
mutable struct BufferedIRCurve <: AbstractIRCurve
	buffer :: Dict{Date, Float64}
	curve :: AbstractIRCurve
end

BufferedIRCurve(curve::AbstractIRCurve) = BufferedIRCurve(Dict{Date, Float64}(), curve)

for fun in (:curve_get_name, :curve_get_daycount, :curve_get_compounding, :curve_get_method, :curve_get_date, :curve_get_dtm, :curve_get_zero_rates, :curve_get_model_parameters, :curve_get_spline_fit_on_rates, :curve_get_spline_fit_on_discount_factors)
	@eval begin
		($fun)(curve::BufferedIRCurve) = ($fun)(curve.curve)
	end
end

curve_get_dict_parameter(curve::BufferedIRCurve, sym::Symbol) = curve_get_dict_parameter(curve.curve, sym)

function zero_rate(curve::BufferedIRCurve, maturity::Date)
	if !haskey(curve.buffer, maturity)
		curve.buffer[maturity] = _zero_rate(curve_get_method(curve), curve, maturity)
	end
	return curve.buffer[maturity]
end

function zero_rate(curve::BufferedIRCurve, maturity_vec::Vector{Date})
	n = length(maturity_vec)
	result = Vector{Float64}(n)
	for i in 1:n
		result[i] = zero_rate(curve, maturity_vec[i])
	end
end
