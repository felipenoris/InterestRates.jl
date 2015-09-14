
# Interest Rates calculation

module InterestRates

using BusinessDays
using Base.Dates

export
	DayCountConvention,
	CompoundingType,
	CurveMethod,
	AbstractIRCurve, getcurvename, getcurvedate,
	ERF, ER, discountfactor, zero_rate, forward_rate,
	ERF_to_rate, discountfactor_to_rate,
	isnullcurve

include("types.jl")
export
	curve_get_name, curve_get_daycount, curve_get_compounding,
	curve_get_method, curve_get_date, curve_get_dtm,
	curve_get_zero_rates, curve_get_model_parameters

include("nullcurve.jl")

############# DAYCOUNT #################

daycount(conv::BDays252, date_start::Date, date_end::Date) = Int(bdays(conv.hc, date_start, date_end))
daycount(::Actual360, date_start::Date, date_end::Date) = Int(date_end - date_start)
daycount(::Actual365, date_start::Date, date_end::Date) = Int(date_end - date_start)

advancedays(conv::BDays252, date_start::Date, daycount::Int) = advancebdays(conv.hc, date_start, daycount)
advancedays(::Actual360, date_start::Date, daycount::Int) = date_start + Day(daycount)
advancedays(::Actual365, date_start::Date, daycount::Int) = date_start + Day(daycount)

function advancedays(conv::DayCountConvention, date_start::Date, daycount_vec::Vector{Int})
	l = length(daycount_vec)
	result = Array(Date, l)
	for i in 1:l
		result[i] = advancedays(conv, date_start, daycount_vec[i])
	end
	return result
end

daysperyear(::BDays252) = 252
daysperyear(::Actual360) = 360
daysperyear(::Actual365) = 365

yearfraction(conv::DayCountConvention, date_start::Date, date_end::Date) = daycount(conv, date_start, date_end) / daysperyear(conv)
yearfraction(curve::AbstractIRCurve, maturity::Date) = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity)

######### COMPOUNDING TYPE ############

# Effective Rate Factor
_ERF(::ContinuousCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : exp(r*t)
_ERF(::SimpleCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : 1.0 + r*t
_ERF(::ExponentialCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : (1.0+r)^t
_ERF(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = _ERF(ct, r, yearfraction(dcc, date_start, date_end))
ERF(curve::AbstractIRCurve, maturity::Date) = _ERF(curve_get_compounding(curve), curve_get_daycount(curve), zero_rate(curve, maturity), curve_get_date(curve), maturity)
ERF(curve::AbstractIRCurve, forward_date::Date, maturity::Date) = ERF(curve, maturity) / ERF(curve, forward_date)

_ERF_to_rate(::ContinuousCompounding, ERF::Float64, t::Float64) = log(ERF) / t
_ERF_to_rate(::SimpleCompounding, ERF::Float64, t::Float64) = (ERF-1.0) / t
_ERF_to_rate(::ExponentialCompounding, ERF::Float64, t::Float64) = ERF^(1.0/t) - 1.0
ERF_to_rate(curve::AbstractIRCurve, ERF::Float64, t::Float64) = _ERF_to_rate(curve_get_compounding(curve), ERF, t)

discountfactor_to_rate(c::CompoundingType, _discountfactor_::Float64, t::Float64) = _ERF_to_rate(c, 1.0 / _discountfactor_, t)

function discountfactor_to_rate(c::CompoundingType, _discountfactor_vec_::Vector{Float64}, t_vec::Vector{Float64})
	l = length(_discountfactor_vec_)

	if l != length(t_vec)
		error("_discountfactor_vec_ and t_vec must have the same length. ($l != $(length(t_vec)))")
	end

	result = Array(Float64, l)
	for i in 1:l
		result[i] = discountfactor_to_rate(c, _discountfactor_vec_[i], t_vec[i])
	end

	return result
end

# Effective Rate = [Effective Rate Factor] - 1
_ER(c::CompoundingType, r::Float64, t::Float64) = _ERF(c, r, t) - 1.0
_ER(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = _ER(ct, r, yearfraction(dcc, date_start, date_end))
ER(curve::AbstractIRCurve, maturity::Date) = _ER(curve_get_compounding(curve), curve_get_daycount(curve), zero_rate(curve, maturity), curve_get_date(curve), maturity)
ER(curve::AbstractIRCurve, forward_date::Date, maturity::Date) =  ERF(curve, forward_date, maturity) - 1.0

# [Discount Factor] = 1 / [Effective Rate Factor]
_discountfactor(ct::CompoundingType, r::Float64, t::Float64) = 1.0 / _ERF(ct, r, t)
_discountfactor(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = _discountfactor(ct, r, yearfraction(dcc, date_start, date_end))
discountfactor(curve::AbstractIRCurve, maturity::Date) = _discountfactor(curve_get_compounding(curve), curve_get_daycount(curve), zero_rate(curve, maturity), curve_get_date(curve), maturity)

# Vector function for ERF and discountfactor functions
for fun in (:ERF, :discountfactor)
	@eval begin
		function ($fun)(curve::AbstractIRCurve, maturity_vec::Vector{Date})
			l = length(maturity_vec)
			_zero_rate_vec_ = zero_rate(curve, maturity_vec)
			result = Array(Float64, l)
			for i = 1:l
				result[i] = $(symbol('_', fun))(curve_get_compounding(curve), curve_get_daycount(curve), _zero_rate_vec_[i], curve_get_date(curve), maturity_vec[i])
			end
			return result
		end
	end
end

forward_rate(curve::AbstractIRCurve, forward_date::Date, maturity::Date) = ERF_to_rate(curve, ERF(curve, forward_date, maturity), yearfraction(curve_get_daycount(curve), forward_date, maturity))

function days_to_maturity(curve::AbstractIRCurve, maturity::Date)
	const d = daycount(curve_get_daycount(curve), curve_get_date(curve), maturity)
	if d < 0
		error("Maturity date $(maturity) should be greater than curve observation date $(curve.dt_observation)")
	end
	return d
end

# Let's use the curve's method to multiple-dispatch. Ugly methods _zero_rate are not exported.
zero_rate(curve::AbstractIRCurve, maturity::Date) = _zero_rate(curve_get_method(curve), curve, maturity)
zero_rate(curve::AbstractIRCurve, maturity_vec::Vector{Date}) = _zero_rate(curve_get_method(curve), curve, maturity_vec)	

include("methods.jl") # implements various _zero_rate() methods for each CurveMethod

end # module InterestRates
