
# Types for module InterestRates

abstract DayCountConvention
type Actual360 <: DayCountConvention end
type Actual365 <: DayCountConvention end

type BDays252 <: DayCountConvention
	hc::HolidayCalendar
end

abstract CompoundingType
type ContinuousCompounding <: CompoundingType end   # exp(rt)
type SimpleCompounding <: CompoundingType end       # (1+r*t)
type ExponentialCompounding <: CompoundingType end  # (1+r)^t

abstract CurveMethod
abstract Parametric <: CurveMethod
abstract Interpolation <: CurveMethod
abstract DiscountFactorInterpolation <: Interpolation
abstract RateInterpolation <: Interpolation

type CubicSplineOnRates <: RateInterpolation end
type CubicSplinesOnDiscountFactors <: DiscountFactorInterpolation end
type FlatForward <: DiscountFactorInterpolation end
type Linear <: RateInterpolation end
type NelsonSiegel <: Parametric end
type Svensson <: Parametric end
type StepFunction <: RateInterpolation end

type CompositeInterpolation <: Interpolation
	before_first::Interpolation
	inner::Interpolation
	after_last::Interpolation
end

abstract AbstractIRCurve
type IRCurve <: AbstractIRCurve
	name::ASCIIString
	daycount::DayCountConvention
	compounding::CompoundingType
	method::CurveMethod
	dt_observation::Date
	parameters_id::Vector{Int} # for interpolation methods, id stores days_to_maturity on curve's daycount convention.
	parameters_values::Vector{Float64}

	# Constructor check inputs
	IRCurve(name::ASCIIString, daycount::DayCountConvention,
		compounding::CompoundingType, method::CurveMethod,
		dt_observation::Date, parameters_id::Vector{Int},
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

		new(name, daycount, compounding, method, dt_observation, parameters_id, parameters_values)
	end
end

### Null curve ###
type NullIRCurve <: AbstractIRCurve end
