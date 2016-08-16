
#
# Compares the performance of Dict based parameters versus type based parameters
# Dict based parameters is implemented in DictCurve type.
# Type based parameters is implemented in SvenssonCurve type.
# SvenssonCurveNullable is the same as SvenssonCurve but has nullable parameters.
# Array based parameters is implemented in ArrayCurve type.
#
# Type and Array based parameters are equivalent in performance.
# Dict based parameters doubles the time execution compared to the other methods.
#

using Base.Test

type DictCurve
	params::Dict{Symbol, Float64}
end

type SvenssonCurve
	beta1::Float64
	beta2::Float64
	beta3::Float64
	beta4::Float64
	lambda1::Float64
	lambda2::Float64
end

type SvenssonCurveNullable
	beta1::Nullable{Float64}
	beta2::Nullable{Float64}
	beta3::Nullable{Float64}
	beta4::Nullable{Float64}
	lambda1::Nullable{Float64}
	lambda2::Nullable{Float64}
end

type ArrayCurve
	params::Array{Float64}
end

function zero_rate(curve::ArrayCurve, t::Float64)
	
	# beta1 = param[1]
	# beta2 = param[2]
	# beta3 = param[3]
	# beta4 = param[4]
	# lambda1 = param[5]
	# lambda2 = param[6]

	_exp_lambda1_t_ = exp(-curve.params[5]*t)
	_exp_lambda2_t_ = exp(-curve.params[6]*t)
	F_beta2 = (1.0 - _exp_lambda1_t_) / (curve.params[5]*t)
	
	return curve.params[1] + curve.params[2]*F_beta2 + curve.params[3]*(F_beta2 - _exp_lambda1_t_) + 
			curve.params[4]*( (1.0 - _exp_lambda2_t_)/(curve.params[6]*t) - _exp_lambda2_t_)
end

function zero_rate(curve::SvenssonCurve, t::Float64)
	
	# beta1 = param[1]
	# beta2 = param[2]
	# beta3 = param[3]
	# beta4 = param[4]
	# lambda1 = param[5]
	# lambda2 = param[6]

	_exp_lambda1_t_ = exp(-curve.lambda1*t)
	_exp_lambda2_t_ = exp(-curve.lambda2*t)
	F_beta2 = (1.0 - _exp_lambda1_t_) / (curve.lambda1*t)
	
	return curve.beta1 + curve.beta2*F_beta2 + curve.beta3*(F_beta2 - _exp_lambda1_t_) + 
			curve.beta4*( (1.0 - _exp_lambda2_t_)/(curve.lambda2*t) - _exp_lambda2_t_)
end

function zero_rate(curve::SvenssonCurveNullable, t::Float64)
	
	# beta1 = param[1]
	# beta2 = param[2]
	# beta3 = param[3]
	# beta4 = param[4]
	# lambda1 = param[5]
	# lambda2 = param[6]

	_exp_lambda1_t_ = exp(-get(curve.lambda1)*t)
	_exp_lambda2_t_ = exp(-get(curve.lambda2)*t)
	F_beta2 = (1.0 - _exp_lambda1_t_) / (get(curve.lambda1)*t)
	
	return get(curve.beta1) + get(curve.beta2)*F_beta2 + get(curve.beta3)*(F_beta2 - _exp_lambda1_t_) + 
			get(curve.beta4)*( (1.0 - _exp_lambda2_t_)/(get(curve.lambda2)*t) - _exp_lambda2_t_)
end

function zero_rate(curve::DictCurve, t::Float64)
	
	# beta1 = param[1]
	# beta2 = param[2]
	# beta3 = param[3]
	# beta4 = param[4]
	# lambda1 = param[5]
	# lambda2 = param[6]

	_exp_lambda1_t_ = exp(-curve.params[:lambda1]*t)
	_exp_lambda2_t_ = exp(-curve.params[:lambda2]*t)
	F_beta2 = (1.0 - _exp_lambda1_t_) / (curve.params[:lambda1]*t)
	
	return curve.params[:beta1] + curve.params[:beta2]*F_beta2 + curve.params[:beta3]*(F_beta2 - _exp_lambda1_t_) + 
			curve.params[:beta4]*( (1.0 - _exp_lambda2_t_)/(curve.params[:lambda2]*t) - _exp_lambda2_t_)
end

params = [0.1, 0.2, 0.3, 0.4, 0.5, 0.8]

params_dict = Dict(:beta1=>params[1], :beta2=>params[2], :beta3=>params[3], :beta4=>params[4], 
				:lambda1=>params[5], :lambda2=>params[6])

d_curve = DictCurve(params_dict)
s_curve = SvenssonCurve(params...)
sn_curve = SvenssonCurveNullable(Nullable(params[1]), Nullable(params[2]), Nullable(params[3]), Nullable(params[4]), Nullable(params[5]), Nullable(params[6]))
a_curve = ArrayCurve(params)

mat_vec = linspace(0.1, 10.0, 1000000)

 # warmup
zero_rate(d_curve, mat_vec[1])
zero_rate(s_curve, mat_vec[1])
zero_rate(sn_curve, mat_vec[1])
zero_rate(a_curve, mat_vec[1])

println("Dict based parameters")
@time for t in mat_vec
	zero_rate(d_curve, t)
end

println("Type based parameters")
@time for t in mat_vec
	zero_rate(s_curve, t)
end

println("Type based nullable parameters")
@time for t in mat_vec
	zero_rate(sn_curve, t)
end

println("Array based parameters")
@time for t in mat_vec
	zero_rate(a_curve, t)
end
