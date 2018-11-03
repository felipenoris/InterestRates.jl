
# Types for module InterestRates

"""
The type `DayCountConvention` sets the convention on how to count the number of days between dates, and also how to convert that number of days into a year fraction.

Given an initial date `D1` and a final date `D2`, here's how the distance between `D1` and `D2` are mapped into a year fraction for each supported day count convention:

* *Actual360* : `(D2 - D1) / 360`
* *Actual365* : `(D2 - D1) / 365`
* *BDays252* : `bdays(D1, D2) / 252`, where `bdays` is the business days between `D1` and `D2` from [BusinessDays.jl package](https://github.com/felipenoris/BusinessDays.jl).
"""
abstract type DayCountConvention end
struct Actual360 <: DayCountConvention end
struct Actual365 <: DayCountConvention end

mutable struct BDays252 <: DayCountConvention
    hc::HolidayCalendar
end

"""
The type `CompoundingType` sets the convention on how to convert a yield into an Effective Rate Factor.

Given a yield `r` and a maturity year fraction `t`, here's how each supported compounding type maps the yield to Effective Rate Factors:

* *ContinuousCompounding* : `exp(r*t)`
* *SimpleCompounding* : `(1+r*t)`
* *ExponentialCompounding* : `(1+r)^t`
"""
abstract type CompoundingType end
struct ContinuousCompounding <: CompoundingType end   # exp(r*t)
struct SimpleCompounding <: CompoundingType end       # (1+r*t)
struct ExponentialCompounding <: CompoundingType end  # (1+r)^t

"""
This package provides the following curve methods.

**Interpolation Methods**

* **Linear**: provides Linear Interpolation on rates.
* **FlatForward**: provides Flat Forward interpolation, which is implemented as a Linear Interpolation on the *log* of discount factors.
* **StepFunction**: creates a step function around given data points.
* **CubicSplineOnRates**: provides *natural cubic spline* interpolation on rates.
* **CubicSplineOnDiscountFactors**: provides *natural cubic spline* interpolation on discount factors.
* **CompositeInterpolation**: provides support for different interpolation methods for: (1) extrapolation before first data point (`before_first`), (2) interpolation between the first and last point (`inner`), (3) extrapolation after last data point (`after_last`).

For *Interpolation Methods*, the field `dtm` holds the number of days between `date` and the maturity of the observed yield, following the curve's day count convention, which must be given in advance, when creating an instance of the curve. The field `zero_rates` holds the yield values for each maturity provided in `dtm`. All yields must be anual based, and must also be given in advance, when creating the instance of the curve.

**Term Structure Models**

* **NelsonSiegel**: term structure model based on *Nelson, C.R., and A.F. Siegel (1987), Parsimonious Modeling of Yield Curve, The Journal of Business, 60, 473-489*.
* **Svensson**: term structure model based on *Svensson, L.E. (1994), Estimating and Interpreting Forward Interest Rates: Sweden 1992-1994, IMF Working Paper, WP/94/114*.

For *Term Structure Models*, the field `parameters` holds the constants defined by each model, as described below. They must be given in advance, when creating the instance of the curve.

For **NelsonSiegel** method, the array `parameters` holds the following parameters from the model:
* **beta1** = parameters[1]
* **beta2** = parameters[2]
* **beta3** = parameters[3]
* **lambda** = parameters[4]

For **Svensson** method, the array `parameters` hold the following parameters from the model:
* **beta1** = parameters[1]
* **beta2** = parameters[2]
* **beta3** = parameters[3]
* **beta4** = parameters[4]
* **lambda1** = parameters[5]
* **lambda2** = parameters[6]

### Methods hierarchy

As a summary, curve methods are organized by the following hierarchy.

* `<<CurveMethod>>`
    * `<<Interpolation>>`
        * `<<DiscountFactorInterpolation>>`
            * `CubicSplineOnDiscountFactors`
            * `FlatForward`
        * `<<RateInterpolation>>`
            * `CubicSplineOnRates`
            * `Linear`
            * `StepFunction`
        * `CompositeInterpolation`
    * `<<Parametric>>`
        * `NelsonSiegel`
        * `Svensson`
"""
abstract type CurveMethod end
abstract type Parametric <: CurveMethod end
abstract type Interpolation <: CurveMethod end

abstract type DiscountFactorInterpolation <: Interpolation end
abstract type RateInterpolation <: Interpolation end

struct CubicSplineOnRates <: RateInterpolation end
struct CubicSplineOnDiscountFactors <: DiscountFactorInterpolation end
struct FlatForward <: DiscountFactorInterpolation end
struct Linear <: RateInterpolation end
struct NelsonSiegel <: Parametric end
struct Svensson <: Parametric end
struct StepFunction <: RateInterpolation end

mutable struct CompositeInterpolation <: Interpolation
    before_first::Interpolation # Interpolation method to be applied before the first point
    inner::Interpolation
    after_last::Interpolation # Interpolation method to be applied after the last point
end

# Helper functions to identify cubic spline method
is_cubic_spline_on_rates(m::CurveMethod) = false
is_cubic_spline_on_rates(m::CubicSplineOnRates) = true
is_cubic_spline_on_rates(m::CompositeInterpolation) = is_cubic_spline_on_rates(m.before_first) || is_cubic_spline_on_rates(m.inner) || is_cubic_spline_on_rates(m.after_last)
is_cubic_spline_on_discount_factors(m::CurveMethod) = false
is_cubic_spline_on_discount_factors(m::CubicSplineOnDiscountFactors) = true
is_cubic_spline_on_discount_factors(m::CompositeInterpolation) = is_cubic_spline_on_discount_factors(m.before_first) || is_cubic_spline_on_discount_factors(m.inner) || is_cubic_spline_on_discount_factors(m.after_last)

abstract type AbstractIRCurve end

# Helper function to create splinefit results for method CubicSplineOnDiscountFactors
function _splinefit_discountfactors(curve::AbstractIRCurve)
    dtm_vec = curve_get_dtm(curve)
    curve_rates_vec = curve_get_zero_rates(curve)
    l = length(dtm_vec)
    yf_vec = Vector{Float64}(undef, l)
    discount_vec = Vector{Float64}(undef, l)

    for i = 1:l
        @inbounds yf_vec[i] = dtm_vec[i] / daysperyear(curve_get_daycount(curve))
        @inbounds discount_vec[i] = discountfactor(curve_get_compounding(curve), curve_rates_vec[i], yf_vec[i])
    end

    return splinefit(yf_vec, discount_vec)
end

mutable struct IRCurve <: AbstractIRCurve
    name::String
    daycount::DayCountConvention
    compounding::CompoundingType
    method::CurveMethod
    date::Date
    dtm::Vector{Int} # for interpolation methods, stores days_to_maturity on curve's daycount convention.
    zero_rates::Vector{Float64} # for interpolation methods, parameters[i] stores yield for maturity dtm[i].
    parameters::Vector{Float64} # for parametric methods, parameters stores model's constant parameters.
    dict::Dict{Symbol, Any}     # holds pre-calculated values for optimization, or additional parameters.

    # Constructor for Interpolation methods
    function IRCurve(name::AbstractString, _daycount::DayCountConvention,
        compounding::CompoundingType, method::M,
        date::Date, dtm::Vector{Int},
        zero_rates::Vector{Float64}, parameters = Vector{Float64}(), dict = Dict{Symbol, Any}()) where {M<:Interpolation}

        @assert !isempty(dtm) "Empty days-to-maturity vector"
        @assert !isempty(zero_rates) "Empty zero_rates vector"
        @assert length(dtm) == length(zero_rates) "dtm and zero_rates must have the same length"
        @assert issorted(dtm) "dtm should be sorted before creating IRCurve instance"

        new_curve = new(String(name), _daycount, compounding, method, date, dtm, zero_rates, parameters, dict)

        # Stores splinefit results for Cubic Spline methods
        if is_cubic_spline_on_rates(method)
            sp = splinefit(curve_get_dtm(new_curve), curve_get_zero_rates(new_curve))
            curve_set_dict_parameter!(new_curve, :spline_fit_on_rates, sp)
        end

        if is_cubic_spline_on_discount_factors(method)
            sp = _splinefit_discountfactors(new_curve)
            curve_set_dict_parameter!(new_curve, :spline_fit_on_discount_factors, sp)
        end

        return new_curve
    end

    # Constructor for Parametric methods
    function IRCurve(name::AbstractString, _daycount::DayCountConvention,
        compounding::CompoundingType, method::M,
        date::Date,
        parameters::Vector{Float64},
        dict = Dict{Symbol, Any}()) where {M<:Parametric}

        @assert !isempty(parameters) "Empty yields vector"
        new(String(name), _daycount, compounding, method, date, Vector{Int}(), Vector{Float64}(), parameters, dict)
    end
end

# Interface for curve types
"""
    curve_get_name(curve::AbstractIRCurve) → String

Returns the name of the curve.
"""
curve_get_name(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_daycount(curve::AbstractIRCurve) → DayCountConvention

Returns the DayCountConvention used by the curve. See DayCountConvention documentation.
"""
curve_get_daycount(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_compounding(curve::AbstractIRCurve) → CompoundingType

Returns the CompoundingType used by the curve. See CompoundingType documentation.
"""
curve_get_compounding(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_method(curve::AbstractIRCurve) → CurveMethod

Returns the CurveMethod used by the curve. See CurveMethod documentation.
"""
curve_get_method(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_date(curve::AbstractIRCurve) → Date

Returns the date when the curve is observed. All zero rate calculation will be performed based on this date.
"""
curve_get_date(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_dtm(curve::AbstractIRCurve) → Vector{Int}

Used for interpolation methods, returns `days_to_maturity` on curve's daycount convention.
"""
curve_get_dtm(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_zero_rates(curve::AbstractIRCurve) → Vector{Float64}

Used for interpolation methods, parameters[i] returns yield for maturity dtm[i].
"""
curve_get_zero_rates(curve::AbstractIRCurve) = error("method not defined")

"""
    curve_get_model_parameters(curve::AbstractIRCurve) → Vector{Float64}

Used for parametric methods, returns model's constant parameters.
"""
curve_get_model_parameters(curve::AbstractIRCurve) = error("method not defined")

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

function curve_get_spline_fit_on_rates(curve::IRCurve) :: Spline
    @assert is_cubic_spline_on_rates(curve_get_method(curve)) "Curve $(curve_get_name(curve)) with method $(curve_get_method(curve)) does not hold a spline_fit_on_rates result."
    return curve_get_dict_parameter(curve, :spline_fit_on_rates)
end

function curve_get_spline_fit_on_discount_factors(curve::IRCurve) :: Spline
    @assert is_cubic_spline_on_discount_factors(curve_get_method(curve)) "Curve $(curve_get_name(curve)) with method $(curve_get_method(curve)) does not hold a spline_fit_on_discount_factors result."
    return curve_get_dict_parameter(curve, :spline_fit_on_discount_factors)
end
