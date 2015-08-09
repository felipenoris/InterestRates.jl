
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

######## NULL CURVE ##########

ERF(curve::NullIRCurve, maturity::Date) = 1.0
ER(curve::NullIRCurve, maturity::Date) = 0.0
discountfactor(curve::NullIRCurve, maturity::Date) = 1.0
getcurvename(curve::NullIRCurve) = "NullCurve"
isnullcurve(curve::NullIRCurve) = true
isnullcurve(curve::AbstractIRCurve) = false
forward_rate(curve::NullIRCurve, forward_date::Date, maturity::Date) = 0.0
zero_rate(curve::NullIRCurve, maturity::Date) = 0.0
zero_rate(curve::NullIRCurve, maturity_vec::Vector{Date}) = zeros(length(maturity_vec))


############# DAYCOUNT #################

daycount(conv::BDays252, date_start::Date, date_end::Date) = Int(bdays(conv.hc, date_start, date_end))
daycount(::Actual360, date_start::Date, date_end::Date) = Int(date_end - date_start)
daycount(::Actual365, date_start::Date, date_end::Date) = Int(date_end - date_start)

daysperyear(::BDays252) = 252
daysperyear(::Actual360) = 360
daysperyear(::Actual365) = 365

yearfraction(conv::DayCountConvention, date_start::Date, date_end::Date) = daycount(conv, date_start, date_end) / daysperyear(conv)

######### COMPOUNDING TYPE ############

# Effective Rate Factor
_ERF(::ContinuousCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : exp(r*t)
_ERF(::SimpleCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : 1.0 + r*t
_ERF(::ExponentialCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : (1.0+r)^t
_ERF(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = _ERF(ct, r, yearfraction(dcc, date_start, date_end))
ERF(curve::IRCurve, maturity::Date) = _ERF(curve.compounding, curve.daycount, zero_rate(curve, maturity), curve.dt_observation, maturity)
ERF(curve::IRCurve, forward_date::Date, maturity::Date) = ERF(curve, maturity) / ERF(curve, forward_date)

_ERF_to_rate(::ContinuousCompounding, ERF::Float64, t::Float64) = log(ERF) / t
_ERF_to_rate(::SimpleCompounding, ERF::Float64, t::Float64) = (ERF-1.0) / t
_ERF_to_rate(::ExponentialCompounding, ERF::Float64, t::Float64) = ERF^(1.0/t) - 1.0
ERF_to_rate(curve::IRCurve, ERF::Float64, t::Float64) = _ERF_to_rate(curve.compounding, ERF, t)

discountfactor_to_rate(c::CompoundingType, _discountfactor_::Float64, t::Float64) = _ERF_to_rate(c, 1.0 / _discountfactor_, t)

# Effective Rate = [Effective Rate Factor] - 1
_ER(c::CompoundingType, r::Float64, t::Float64) = _ERF(c, r, t) - 1.0
_ER(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = _ER(ct, r, yearfraction(dcc, date_start, date_end))
ER(curve::IRCurve, maturity::Date) = _ER(curve.compounding, curve.daycount, zero_rate(curve, maturity), curve.dt_observation, maturity)
ER(curve::AbstractIRCurve, forward_date::Date, maturity::Date) =  ERF(curve, forward_date, maturity) - 1.0

# [Discount Factor] = 1 / [Effective Rate Factor]
_discountfactor(ct::CompoundingType, r::Float64, t::Float64) = 1.0 / _ERF(ct, r, t)
_discountfactor(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = _discountfactor(ct, r, yearfraction(dcc, date_start, date_end))
discountfactor(curve::IRCurve, maturity::Date) = _discountfactor(curve.compounding, curve.daycount, zero_rate(curve, maturity), curve.dt_observation, maturity)

# Vector function for ERF and discountfactor functions
for fun in (:ERF, :discountfactor)
	@eval begin
		function ($fun)(curve::IRCurve, maturity_vec::Vector{Date})
			l = length(maturity_vec)
			_zero_rate_vec_ = zero_rate(curve, maturity_vec)
			result = Array(Float64, l)
			for i = 1:l
				result[i] = $(symbol('_', fun))(curve.compounding, curve.daycount, _zero_rate_vec_[i], curve.dt_observation, maturity_vec[i])
			end
			return result
		end
	end
end

########## INTEREST RATE CURVES #############

# Access basic curve properties
getcurvename(curve::IRCurve) = curve.name
getcurvedate(curve::IRCurve) = curve.dt_observation

forward_rate(curve::IRCurve, forward_date::Date, maturity::Date) = ERF_to_rate(curve, ERF(curve, forward_date, maturity), yearfraction(curve.daycount, forward_date, maturity))

function days_to_maturity(curve::IRCurve, maturity::Date)
	const d = daycount(curve.daycount, curve.dt_observation, maturity)
	if d < 0
		error("Maturity date $(maturity) should be greater than curve observation date $(curve.dt_observation)")
	end
	return d
end

# Let's use the curve's method to multiple-dispatch. Ugly methods _zero_rate are not exported.
zero_rate(curve::IRCurve, maturity::Date) = _zero_rate(curve.method, curve, maturity)
zero_rate(curve::IRCurve, maturity_vec::Vector{Date}) = _zero_rate(curve.method, curve, maturity_vec)	

include("methods.jl")

end # module InterestRates