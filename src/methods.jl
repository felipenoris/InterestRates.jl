
# Curve methods implementation

_zero_rate{METHOD<:RateInterpolation}(method::METHOD, curve::IRCurve, maturity::Date) = _zero_rate(method, curve.parameters_id, curve.parameters_values, days_to_maturity(curve, maturity))

function _zero_rate(comp::CompositeInterpolation, curve::IRCurve, maturity::Date)
	dtm = days_to_maturity(curve, maturity)

	if dtm < curve.parameters_id[1]
		return _zero_rate(comp.before_first, curve, maturity)
	elseif dtm > curve.parameters_id[end]
		return _zero_rate(comp.after_last, curve, maturity)
	else
		return _zero_rate(comp.inner, curve, maturity)
	end
end

function _interpolationpoints(x::Vector{Int}, y::Vector{Float64}, x_out::Int)
	index_a::Int
	index_b::Int

	if x_out <= x[1]
		# Interpolation point is before first vertice
		# Slope will be determined by the 1st and 2nd vertices
		index_a = 1
		index_b = 2
	elseif x_out >= x[end]
		# Interpolation point is after last vertice
		# Slope will be determined by the last and last-1 vertices
		index_b = length(x)
		index_a = index_b - 1
	else
		# Inner point
		index_a =  findlast(a -> a < x_out, x) # last element before x_out on x
		index_b = findfirst(b -> b >=  x_out, x) # first element after x_out on x
	end
	
	Xa = x[index_a]
	Xb = x[index_b]
	Ya = y[index_a]
	Yb = y[index_b]
	
	return Xa, Ya, Xb, Yb
end

# Perform Linear interpolation. Slope is determined by points (Xa, Ya) and (Xb, Yb).
# Interpolation occurs on point (x_out, returnvalue)
_linearinterp{TX, TY}(Xa::TX, Ya::TY, Xb::TX, Yb::TY, x_out::TX) = (x_out - Xa) * (Yb - Ya) / (Xb - Xa) + Ya

# Linear interpolation of zero_rates
function _zero_rate(::Linear, x::Vector{Int}, y::Vector{Float64}, x_out::Int)
	# If this curve has only 1 vertice, this will be a flat curve
	if length(x) == 1
		return y[1]
	end
	
	Xa, Ya, Xb, Yb = _interpolationpoints(x, y, x_out)
	return _linearinterp(Xa, Ya, Xb, Yb, x_out)
end

# Step Function
function _zero_rate(::StepFunction, x::Vector{Int}, y::Vector{Float64}, x_out::Int)
	# If this curve has only 1 vertice, this will be a flat curve
	if length(x) == 1
		return y[1]
	end

	if x_out <= x[1]
		# Interpolation point is before first vertice
		# The result will be extrapolated using the first vertice zero_rate
		return y[1]
	elseif x_out >= x[end]
		# Interpolation point is after last vertice
		# The result will be extrapolated using the last vertice zero_rate
		return y[end]
	else
		# Inner point
		return y[findlast(a -> a <= x_out, x)] # last element before x_out on x
	end
end

# Flat Forward is linear interpolation on the log of discountfactors
# Maybe not useful for SimpleCompounding curves.
function _zero_rate(::FlatForward, curve::IRCurve, maturity::Date)
	# If this curve has only 1 vertice, this will be a flat curve
	if length(curve.parameters_values) == 1
		return curve.parameters_values[1]
	end
	
	x_out = days_to_maturity(curve, maturity)
	Xa, Ya, Xb, Yb = _interpolationpoints(curve.parameters_id, curve.parameters_values, x_out)

	_daysperyear_ = daysperyear(curve.daycount)
	year_fraction_a = Xa / _daysperyear_
	logPa = log(_discountfactor(curve.compounding, Ya, year_fraction_a))
	
	year_fraction_b = Xb / _daysperyear_
	logPb = log(_discountfactor(curve.compounding, Yb, year_fraction_b))
	
	year_fraction_x = x_out / _daysperyear_
	logPx = _linearinterp(year_fraction_a, logPa, year_fraction_b, logPb, year_fraction_x)

	return discountfactor_to_rate(curve.compounding, exp(logPx), year_fraction_x)
end

function _zero_rate(::NelsonSiegel, curve::IRCurve, maturity::Date)
	
	# beta1 = param[1]
	# beta2 = param[2]
	# beta3 = param[3]
	# lambda = param[4]

	param = curve.parameters_values
	t = yearfraction(curve, maturity)
	_exp_lambda_t_ = exp(-param[4]*t)
	F_beta2 = (1.0 - _exp_lambda_t_) / (param[4]*t)
	
	return param[1] + param[2]*F_beta2 + param[3]*(F_beta2 - _exp_lambda_t_)
end

function _zero_rate(::Svensson, curve::IRCurve, maturity::Date)
	
	# beta1 = param[1]
	# beta2 = param[2]
	# beta3 = param[3]
	# beta4 = param[4]
	# lambda1 = param[5]
	# lambda2 = param[6]

	param = curve.parameters_values
	t = yearfraction(curve, maturity)
	_exp_lambda1_t_ = exp(-param[5]*t)
	_exp_lambda2_t_ = exp(-param[6]*t)
	F_beta2 = (1.0 - _exp_lambda1_t_) / (param[5]*t)
	
	return param[1] + param[2]*F_beta2 + param[3]*(F_beta2 - _exp_lambda1_t_) + 
			param[4]*( (1.0 - _exp_lambda2_t_)/(param[6]*t) - _exp_lambda2_t_)
end

include("splines.jl")

function _zero_rate(::CubicSplineOnRates, x::Vector{Int}, y::Vector{Float64}, x_out::Int)
	sp = splinefit(x, y)
	return splineint(sp, x_out)
end

function _zero_rate(::CubicSplineOnRates, curve::IRCurve, maturity_vec::Vector{Date})
	sp = splinefit(curve.parameters_id, curve.parameters_values)
	
	l = length(maturity_vec)
	rates = Array(Float64, l)

	for i in 1:l
		dtm = days_to_maturity(curve, maturity_vec[i])
		rates[i] = splineint(sp, dtm)
	end
	return rates
end

# Aux function for _zero_rate(::CubicSplinesOnDiscountFactors, ...) methods
function _splinefit_discountfactors(curve::IRCurve)
	dtm_vec = curve.parameters_id
	curve_rates_vec = curve.parameters_values
	l = length(dtm_vec)
	yf_vec = Array(Float64, l)
	discount_vec = Array(Float64, l)

	for i = 1:l
		yf_vec[i] = dtm_vec[i] / daysperyear(curve.daycount)
		discount_vec[i] = _discountfactor(curve.compounding, curve_rates_vec[i], yf_vec[i])
	end

	return splinefit(yf_vec, discount_vec)
end

function _zero_rate(::CubicSplineOnDiscountFactors, curve::IRCurve, maturity::Date)
	sp = _splinefit_discountfactors(curve)
	yf_maturity = yearfraction(curve.daycount, curve.dt_observation, maturity)
	result_discount_factor = splineint(sp, yf_maturity)
	return discountfactor_to_rate(curve.compounding, result_discount_factor, yf_maturity)
end

function _zero_rate(::CubicSplineOnDiscountFactors, curve::IRCurve, maturity_vec::Vector{Date})
	sp = _splinefit_discountfactors(curve)
	mat_vec_len = length(maturity_vec)
	
	yf_maturity_vec = Array(Float64, mat_vec_len)
	for i in 1:mat_vec_len
		yf_maturity_vec[i] = yearfraction(curve.daycount, curve.dt_observation, maturity_vec[i])
	end

	return discountfactor_to_rate(curve.compounding, splineint(sp, yf_maturity_vec), yf_maturity_vec)
end

# Generate vector functions
for elty in (:FlatForward, :CompositeInterpolation, :StepFunction, :Linear, :NelsonSiegel, :Svensson)
	@eval begin
		function _zero_rate(m::$elty, curve::IRCurve, maturity_vec::Vector{Date})
			l = length(maturity_vec)
			rates = Array(Float64, l)
			for i = 1:l
				rates[i] = _zero_rate(m, curve, maturity_vec[i])
			end
		return rates
		end
	end
end
