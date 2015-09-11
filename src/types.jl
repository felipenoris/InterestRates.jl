
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
	parameters_id::Vector{Int} # for interpolation methods, id stores days_to_maturity on curve's daycount convention.
	parameters_values::Vector{Float64}
	cache::Dict{Symbol, Any}

	# Constructor check inputs
	IRCurve(name::ASCIIString, daycount::DayCountConvention,
		compounding::CompoundingType, method::CurveMethod,
		date::Date, parameters_id::Vector{Int},
		parameters_values::Vector{Float64}) = begin

		if isempty(parameters_id) || isempty(parameters_values)
			error("Empty curve parameter vector")
		end

		if length(parameters_id) != length(parameters_values)
			error("parameters_id and parameters_values must have the same length")
		end

		if !issorted(parameters_id)
			error("parameters_id should be sorted before creating IRCurve instance")
		end

		cache = Dict{Symbol, Any}()

		new(name, daycount, compounding, method, date, parameters_id, parameters_values, cache)
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
curve_get_dtm(curve::IRCurve) = curve.parameters_id
curve_get_zero_rates(curve::IRCurve) = curve.parameters_values
curve_get_model_parameters(curve::IRCurve) = curve.parameters_values
