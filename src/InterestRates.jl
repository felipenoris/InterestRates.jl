
__precompile__(true)
module InterestRates

# 0.4 compat
if !isdefined(Core, :String)
    typealias String UTF8String
end

using BusinessDays
using Base.Dates

export
	ERF, ER, discountfactor, zero_rate, forward_rate,
	ERF_to_rate, discountfactor_to_rate,
	isnullcurve

include("types.jl")
include("nullcurve.jl")
include("composite.jl")

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

advancedays(curve::AbstractIRCurve, daycount) = advancedays(curve_get_daycount(curve), curve_get_date(curve), daycount)

daysperyear(::BDays252) = 252
daysperyear(::Actual360) = 360
daysperyear(::Actual365) = 365

yearfraction(conv::DayCountConvention, date_start::Date, date_end::Date) = daycount(conv, date_start, date_end) / daysperyear(conv)
yearfraction(curve::AbstractIRCurve, maturity::Date) = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity)

######### COMPOUNDING TYPE ############

# Effective Rate Factor
ERF(::ContinuousCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : exp(r*t)
ERF(::SimpleCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : 1.0 + r*t
ERF(::ExponentialCompounding, r::Float64, t::Float64) = t == 0.0 ? 1.0 : (1.0+r)^t
ERF(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = ERF(ct, r, yearfraction(dcc, date_start, date_end))
ERF(curve::AbstractIRCurve, maturity::Date) = ERF(curve_get_compounding(curve), curve_get_daycount(curve), zero_rate(curve, maturity), curve_get_date(curve), maturity)
ERF(curve::AbstractIRCurve, forward_date::Date, maturity::Date) = ERF(curve, maturity) / ERF(curve, forward_date)

ERF_to_rate(::ContinuousCompounding, ERF::Float64, t::Float64) = log(ERF) / t
ERF_to_rate(::SimpleCompounding, ERF::Float64, t::Float64) = (ERF-1.0) / t
ERF_to_rate(::ExponentialCompounding, ERF::Float64, t::Float64) = ERF^(1.0/t) - 1.0
ERF_to_rate(curve::AbstractIRCurve, ERF::Float64, t::Float64) = ERF_to_rate(curve_get_compounding(curve), ERF, t)

discountfactor_to_rate(c::CompoundingType, _discountfactor_::Float64, t::Float64) = ERF_to_rate(c, 1.0 / _discountfactor_, t)

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
ER(c::CompoundingType, r::Float64, t::Float64) = ERF(c, r, t) - 1.0
ER(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = ER(ct, r, yearfraction(dcc, date_start, date_end))
ER(curve::AbstractIRCurve, maturity::Date) = ER(curve_get_compounding(curve), curve_get_daycount(curve), zero_rate(curve, maturity), curve_get_date(curve), maturity)
ER(curve::AbstractIRCurve, forward_date::Date, maturity::Date) =  ERF(curve, forward_date, maturity) - 1.0

# [Discount Factor] = 1 / [Effective Rate Factor]
discountfactor(ct::CompoundingType, r::Float64, t::Float64) = 1.0 / ERF(ct, r, t)
discountfactor(ct::CompoundingType, dcc::DayCountConvention, r::Float64, date_start::Date, date_end::Date) = discountfactor(ct, r, yearfraction(dcc, date_start, date_end))
discountfactor(curve::AbstractIRCurve, maturity::Date) = 1.0 / ERF(curve, maturity)

# Optimized vector functions for `ERF` and `discountfactor` functions
for fun in (:ERF, :discountfactor)
	@eval begin
		function ($fun)(curve::AbstractIRCurve, maturity_vec::Vector{Date})
			len = length(maturity_vec)
			_zero_rate_vec_ = zero_rate(curve, maturity_vec)
			result = Vector{Float64}(len)
			for i = 1:len
				result[i] = $(fun)(curve_get_compounding(curve), curve_get_daycount(curve), _zero_rate_vec_[i], curve_get_date(curve), maturity_vec[i])
			end
			return result
		end
	end
end

forward_rate(curve::AbstractIRCurve, forward_date::Date, maturity::Date) = ERF_to_rate(curve, ERF(curve, forward_date, maturity), yearfraction(curve_get_daycount(curve), forward_date, maturity))

function days_to_maturity(curve::AbstractIRCurve, maturity::Date)
	const d = daycount(curve_get_daycount(curve), curve_get_date(curve), maturity)
	if d < 0
		error("Maturity date $(maturity) should be greater than curve observation date $(curve_get_date(curve))")
	end
	return d
end

# Let's use the curve's method to multiple-dispatch. Ugly methods _zero_rate are not exported.
zero_rate(curve::AbstractIRCurve, maturity::Date) = _zero_rate(curve_get_method(curve), curve, maturity)
zero_rate(curve::AbstractIRCurve, maturity_vec::Vector{Date}) = _zero_rate(curve_get_method(curve), curve, maturity_vec)	

include("methods.jl") # implements various zero_rate() methods for each CurveMethod

end # module InterestRates
