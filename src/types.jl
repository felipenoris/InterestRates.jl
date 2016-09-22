
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
	name::String
	daycount::DayCountConvention
	compounding::CompoundingType
	method::CurveMethod
	date::Date
	dtm::Vector{Int} # for interpolation methods, stores days_to_maturity on curve's daycount convention.
	zero_rates::Vector{Float64} # for interpolation methods, parameters[i] stores yield for maturity dtm[i].
	parameters::Vector{Float64} # for parametric methods, parameters stores model's constant parameters.
	dict::Dict{Symbol, Any}		# holds pre-calculated values for optimization, or additional parameters.

	# Constructor for Interpolation methods
	IRCurve{M<:Interpolation}(name::AbstractString, _daycount::DayCountConvention,
		compounding::CompoundingType, method::M,
		date::Date, dtm::Vector{Int},
		zero_rates::Vector{Float64}, parameters = Array(Float64,0), dict = Dict{Symbol, Any}()) = begin

		isempty(dtm) && error("Empty days-to-maturity vector")
		isempty(zero_rates) && error("Empty zero_rates vector")
		(length(dtm) != length(zero_rates)) && error("dtm and zero_rates must have the same length")
		(!issorted(dtm)) && error("dtm should be sorted before creating IRCurve instance")

		new(String(name), _daycount, compounding, method, date, dtm, zero_rates, parameters, dict)
	end

	# Constructor for Parametric methods
	IRCurve{M<:Parametric}(name::AbstractString, _daycount::DayCountConvention,
		compounding::CompoundingType, method::M,
		date::Date,
		parameters::Vector{Float64},
		dict = Dict{Symbol, Any}()) = begin
		isempty(parameters) && error("Empty yields vector")
		new(String(name), _daycount, compounding, method, date, Array(Int,0), Array(Float64,0), parameters, dict)
	end
end

# Interface for concrete curve types
curve_get_name(curve::AbstractIRCurve) = error("method not defined")
curve_get_daycount(curve::AbstractIRCurve) = error("method not defined")
curve_get_compounding(curve::AbstractIRCurve) = error("method not defined")
curve_get_method(curve::AbstractIRCurve) = error("method not defined")
curve_get_date(curve::AbstractIRCurve) = error("method not defined")
curve_get_dtm(curve::AbstractIRCurve) = error("method not defined")
curve_get_zero_rates(curve::AbstractIRCurve) = error("method not defined")
curve_get_model_parameters(curve::AbstractIRCurve) = error("method not defined")
curve_get_dict_parameter(curve::AbstractIRCurve, sym::Symbol) = error("method not defined")
curve_set_dict_parameter!(curve::AbstractIRCurve, sym::Symbol, value) = error("method not defined")

# AbstractIRCurve interface implementation for IRCurve type
curve_get_name(curve::IRCurve) = curve.name
curve_get_daycount(curve::IRCurve) = curve.daycount
curve_get_compounding(curve::IRCurve) = curve.compounding
curve_get_method(curve::IRCurve) = curve.method
curve_get_date(curve::IRCurve) = curve.date
curve_get_dtm(curve::IRCurve) = curve.dtm
curve_get_zero_rates(curve::IRCurve) = curve.zero_rates
curve_get_model_parameters(curve::IRCurve) = curve.parameters
curve_get_dict_parameter(curve::IRCurve, sym::Symbol) = curve.dict[sym]

function curve_set_dict_parameter!(curve::IRCurve, sym::Symbol, value)
	curve.dict[sym] = value
end
