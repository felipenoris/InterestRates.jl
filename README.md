
# InterestRates.jl

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE)
[![Build Status](https://travis-ci.org/felipenoris/InterestRates.jl.svg?branch=master)](https://travis-ci.org/felipenoris/InterestRates.jl)
[![codecov.io](http://codecov.io/github/felipenoris/InterestRates.jl/coverage.svg?branch=master)](http://codecov.io/github/felipenoris/InterestRates.jl?branch=master)

Tools for **Term Structure of Interest Rates** calculation, aimed at the valuation of financial contracts,
specially *Fixed Income* instruments.

## Installation

```julia
julia> Pkg.add("InterestRates")
```

## Concept

A Term Structure of Interest Rates, also known as *zero-coupon curve*,
is a function `f(t) → y` that maps a given maturity `t` onto the yield `y` of a bond
that matures at `t` and pays no coupons (*zero-coupon bond*).

For instance, say the current price of a bond that pays exactly `10` in `1 year` is
`9.25`. If one buys that bond for the current price and holds it until the maturity
of the contract, that investor will gain `0.75`, which represents `8.11%` of the original price. That means that the bond is currently priced with a yield of `8.11%` *per year*.

It's not feasible to observe prices for each possible maturity. We can observe only
a set of discrete data points of the yield curve. Therefore, in order to determine
the entire term structure, one must choose an interpolation method, or a term structure model.

## Data Structure for Interest Rate Curve

All yield curve calculation is built around `AbstractIRCurve`. The module expects
that the concrete implementations of `AbstractIRCurve` provide the following methods:

* `curve_get_name(curve::AbstractIRCurve) → String`
* `curve_get_daycount(curve::AbstractIRCurve) → DayCountConvention`
* `curve_get_compounding(curve::AbstractIRCurve) → CompoundingType`
* `curve_get_method(curve::AbstractIRCurve) → CurveMethod`
* `curve_get_date(curve::AbstractIRCurve) → Date`, returns the date when the curve is observed.
* `curve_get_dtm(curve::AbstractIRCurve) → Vector{Int}`, used for interpolation methods, returns days_to_maturity on curve's daycount convention.
* `curve_get_zero_rates(curve::AbstractIRCurve) → Vector{Float64}`, used for interpolation methods, parameters[i] returns yield for maturity dtm[i].
* `curve_get_model_parameters(curve::AbstractIRCurve) → Vector{Float64}`, used for parametric methods, returns model's constant parameters.

This package provides a default implementation of `AbstractIRCurve` interface,
which is a *database-friendly* data type: `IRCurve`.

```julia
mutable struct IRCurve <: AbstractIRCurve
	name::String
	daycount::DayCountConvention
	compounding::CompoundingType
	method::CurveMethod
	date::Date
	dtm::Vector{Int}
	zero_rates::Vector{Float64}
	parameters::Vector{Float64}
	dict::Dict{Symbol, Any}		# holds pre-calculated values for optimization, or additional parameters.
#...
```

The type `DayCountConvention` sets the convention on how to count the number of days between dates,
and also how to convert that number of days into a year fraction.

Given an initial date `D1` and a final date `D2`, here's how the distance
between `D1` and `D2` are mapped into a year fraction for each supported day count convention:

* *Actual360* : `(D2 - D1) / 360`
* *Actual365* : `(D2 - D1) / 365`
* *BDays252* : `bdays(D1, D2) / 252`, where `bdays` is the business days
between `D1` and `D2` from [BusinessDays.jl package](https://github.com/felipenoris/BusinessDays.jl).

The type `CompoundingType` sets the convention on how to convert a yield into an Effective Rate Factor.

Given a yield `r` and a maturity year fraction `t`, here's how each supported compounding
type maps the yield to Effective Rate Factors:

* *ContinuousCompounding* : `exp(r*t)`
* *SimpleCompounding* : `(1+r*t)`
* *ExponentialCompounding* : `(1+r)^t`

The `date` field sets the date when the Yield Curve is observed. All zero rate calculation
will be performed based on this date.

The fields `dtm` and `zero_rates` hold the observed market data for the yield curve,
as discussed on *Curve Methods* section.

The field `parameters` holds parameter values for term structure models, as discussed
on *Curve Methods* section.

`dict` is avaliable for additional parameters, and to hold pre-calculated values for optimization.

## Curve Methods

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

For *Term Structure Models*, the field `parameters` holds the constants defined by each model,
as described below. They must be given in advance, when creating the instance of the curve.

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

## Usage

```julia
using InterestRates

# First, create a curve instance.

vert_x = [11, 15, 50, 80] # for interpolation methods, represents the days to maturity
vert_y = [0.10, 0.15, 0.14, 0.17] # yield values

dt_curve = Date(2015,08,03)

mycurve = InterestRates.IRCurve("dummy-simple-linear", InterestRates.Actual365(),
	InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,
	vert_x, vert_y)

# yield for a given maturity date
y = zero_rate(mycurve, Date(2015,08,25))
# 0.148

# forward rate between two future dates
fy = forward_rate(mycurve, Date(2015,08,25), Date(2015, 10, 10))
# 0.16134333771591897

# Discount factor for a given maturity date
df = discountfactor(mycurve, Date(2015,10,10))
# 0.9714060637029466

# Effective Rate Factor for a given maturity
erf = ERF(mycurve, Date(2015,10,10))
# 1.0294356164383562

# Effective Rate for a given maturity
er = ER(mycurve, Date(2015,10,10))
# 0.029435616438356238
```

See `runtests.jl` for more examples.

## Buffered Curve

A `BufferedIRCurve` buffers results of interest rate interpolations.

You can create it by using `InterestRates.BufferedIRCurve(source_curve)` constructor,
where `source_courve` is a given `AbstractIRCurve`.

The first time you ask for a rate, discount factor or effetive factor for a given maturity,
it will apply the source curve computation method. The second time you ask for any information
for the same maturity, it will use the cached value.

**Example:**

```julia
using InterestRates, BusinessDays
const ir = InterestRates

curve_date = Date(2017,3,2)
days_to_maturity = [ 1, 22, 83, 147, 208, 269,
                     332, 396, 458, 519, 581, 711, 834]
rates = [ 0.1213, 0.121875, 0.11359 , 0.10714 , 0.10255 , 0.100527,
0.09935 , 0.09859 , 0.098407, 0.098737, 0.099036, 0.099909, 0.101135]

method = ir.CompositeInterpolation(ir.StepFunction(), # before-first
                                   ir.CubicSplineOnRates(), #inner
                                   ir.FlatForward()) # after-last

curve_brl = ir.IRCurve("Curve BRL", # name
    ir.BDays252(:Brazil), # DayCountConvention
    ir.ExponentialCompounding(), # CompoundingType
    method, # interpolation method
    curve_date, # base date
    days_to_maturity,
    rates);

fixed_maturity = Date(2018,5,3)
@elapsed discountfactor(curve_brl, fixed_maturity)
# 0.178632414

buffered_curve_brl = ir.BufferedIRCurve(curve_brl)
discountfactor(buffered_curve_brl, fixed_maturity) # stores in cache
@elapsed discountfactor(buffered_curve_brl, fixed_maturity) # retrieves stored value in cache
# 3.683e-5
```

## Composite Curves

*Warning: This is an experimental feature. The API may change in the future.*

`InterestRates.CompositeIRCurve(curve_a, curve_b, ...)` will return a composite curve.

Calling `discountfactor` or `ERF` on a composite curve will return the product of the results
of these functions for each curve inside a composite curve.

## Alternative Libraries

* *Ito.jl* : https://github.com/aviks/Ito.jl
* *FinancialMarkets.jl* : https://github.com/imanuelcostigan/FinancialMarkets.jl
