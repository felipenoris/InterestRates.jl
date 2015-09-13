
# Types for module InterestRates

abstract DayCountConvention
type Actual360 <: DayCountConvention end
type Actual365 <: DayCountConvention end

type BDays252 <: DayCountConvention
	hc::HolidayCalendar
end

abstract CompoundingType
type ContinuousCompounding <: CompoundingType end   # exp(r*t)
type SimpleCompounding <: CompoundingType end       # (1+r*t)
type ExponentialCompounding <: CompoundingType end  # (1+r)^t

abstract CurveMethod
abstract Parametric <: CurveMethod
abstract Interpolation <: CurveMethod

abstract DiscountFactorInterpolation <: Interpolation
abstract RateInterpolation <: Interpolation

type CubicSplineOnRates <: RateInterpolation end
type CubicSplineOnDiscountFactors <: DiscountFactorInterpolation end
type FlatForward <: DiscountFactorInterpolation end
type Linear <: RateInterpolation end
type NelsonSiegel <: Parametric end
type Svensson <: Parametric end
type StepFunction <: RateInterpolation end

type CompositeInterpolation <: Interpolation
	before_first::Interpolation # Interpolation method to be applied before the first point
	inner::Interpolation
	after_last::Interpolation # Interpolation method to be applied after the last point
end

abstract AbstractIRCurve

type IRCurve <: AbstractIRCurve
	name::ASCIIString
	daycount::DayCountConvention
	compounding::CompoundingType
	method::CurveMethod
	date::Date
	dtm::Vector{Int} # for interpolation methods, stores days_to_maturity on curve's daycount convention.
	parameters::Vector{Float64} # for interpolation methods, parameters[i] stores yield for maturity dtm[i],
								# for parametric methods, parameters stores model's constant parameters.
	dict::Dict{Symbol, Any}		# holds pre-calculated values for optimization, or additional parameters.

	# Constructor for Interpolation methods
	IRCurve{M<:Interpolation}(name::ASCIIString, daycount::DayCountConvention,
		compounding::CompoundingType, method::M,
		date::Date, dtm::Vector{Int},
		yield_vec::Vector{Float64}, dict = Dict{Symbol, Any}()) = begin

		isempty(dtm) && error("Empty days-to-maturity vector")
		isempty(yield_vec) && error("Empty yields vector")
		(length(dtm) != length(yield_vec)) && error("dtm and yield_vec must have the same length")
		(!issorted(dtm)) && error("dtm should be sorted before creating IRCurve instance")

		new(name, daycount, compounding, method, date, dtm, yield_vec, dict)
	end

	# Constructor for Parametric methods
	IRCurve{M<:Parametric}(name::ASCIIString, daycount::DayCountConvention,
		compounding::CompoundingType, method::M,
		date::Date,
		parameters::Vector{Float64}, dict = Dict{Symbol, Any}()) = begin
		isempty(parameters) && error("Empty yields vector")
		new(name, daycount, compounding, method, date, Array(Int,1), parameters, dict)
	end
end

# methods that should be defined
curve_get_name(curve::AbstractIRCurve) = error("method not defined")
curve_get_daycount(curve::AbstractIRCurve) = error("method not defined")
curve_get_compounding(curve::AbstractIRCurve) = error("method not defined")
curve_get_method(curve::AbstractIRCurve) = error("method not defined")
curve_get_date(curve::AbstractIRCurve) = error("method not defined")
curve_get_dtm(curve::AbstractIRCurve) = error("method not defined")
curve_get_zero_rates(curve::AbstractIRCurve) = error("method not defined")
curve_get_model_parameters(curve::AbstractIRCurve) = error("method not defined")

# Access basic curve properties
curve_get_name(curve::IRCurve) = curve.name
curve_get_daycount(curve::IRCurve) = curve.daycount
curve_get_compounding(curve::IRCurve) = curve.compounding
curve_get_method(curve::IRCurve) = curve.method
curve_get_date(curve::IRCurve) = curve.date
curve_get_dtm(curve::IRCurve) = curve.dtm
curve_get_zero_rates(curve::IRCurve) = curve.parameters
curve_get_model_parameters(curve::IRCurve) = curve.parameters
