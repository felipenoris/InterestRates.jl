# InterestRates.jl [![Build Status](https://travis-ci.org/felipenoris/InterestRates.jl.svg?branch=master)](https://travis-ci.org/felipenoris/InterestRates.jl) [![Coverage Status](https://coveralls.io/repos/felipenoris/InterestRates.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/felipenoris/InterestRates.jl?branch=master) [![codecov.io](http://codecov.io/github/felipenoris/InterestRates.jl/coverage.svg?branch=master)](http://codecov.io/github/felipenoris/InterestRates.jl?branch=master)
Tools for **Term Structure of Interest Rates** calculation, aimed at the valuation of financial contracts, specially *Fixed Income* instruments.

**Installation**: 
```julia
julia> Pkg.update()
julia> Pkg.add("InterestRates")
```
*Current version is v0.0.1*

*Requires Julia v0.4-*

## Concept

A Term Structure of Interest Rates, also known as *zero-coupon curve*, is a function `f(t) -> y` that maps a given maturity `t` onto the yield `y` of a bond that matures at `t` and pays no coupons (*zero-coupon bond*).

For instance, say the current price of a bond that pays exactly `10` in `1 year` is `9.25`. If one buys that bond for the current price and holds it until the maturity of the contract, that investor will gain `0.75`, which represents `8.11%` of the original price. That means that the bond is currently priced with a yield of `8.11%` *per year*.

It's not feasible to observe prices for each possible maturity. We can observe only a set of discrete data points of the yield curve. Therefore, in order to determine the entire term structure, one must choose an interpolation method, or a term structure model.

## Data Structure for Interest Rate Curve

All yield curve calculation is built around a *database-friendly* data type: `IRCurve`.

```julia
type IRCurve <: AbstractIRCurve
	name::ASCIIString # curve name for reference
	daycount::DayCountConvention # convention on how to count number of days between dates
	compounding::CompoundingType # convention on how to convert an interest rate to an effective rate factor
	method::CurveMethod # see Curve Methods section
	dt_observation::Date # reference date for the curve data
	parameters_id::Vector{Int} # for interpolation methods, id stores days_to_maturity on curve's daycount convention.
	parameters_values::Vector{Float64}
#...
```

The type `DayCountConvention` sets the convention on how to count the number of days between dates, and also how to convert that number of days into a year fraction.

Given an initial date `D1` and a final date `D2`, here's how the distance between `D1` and `D2` are mapped into a year fraction for each supported day count convention:

* *Actual360* : `(D2 - D1) / 360`
* *Actual365* : `(D2 - D1) / 365`
* *BDays252* : `bdays(D1, D2) / 252`, where `bdays` is the business days between `D1` and `D2` from `BusinessDays.jl` package.

The type `CompoundingType` sets the convention on how to convert a yield into an Effective Rate Factor.

Given a yield `r` and a maturity year fraction `t`, here's how each supported compounding type maps the yield to Effective Rate Factors:

* *ContinuousCompounding* : `exp(r*t)`
* *SimpleCompounding* : `(1+r*t)`
* *ExponentialCompounding* : `(1+r)^t`

The `dt_observation` field sets the date when the Yield Curve is observed. All zero rate calculation will be performed based on this date.

The fields `parameters_id` and `parameters_values` hold the observed market data for the yield curve, as discussed on *Curve Methods* section.

## Curve Methods

This package provides the following curve methods.

**Interpolation Methods**

* **Linear**: provides Linear Interpolation on rates.
* **FlatForward**: provides Flat Forward interpolation, which is implemented as a Linear Interpolation on the *log* of discount factors.
* **StepFunction**: creates a step function around given data points.
* **CubicSplineOnRates**: provides *natural cubic spline* interpolation on rates.
* **CubicSplineOnDiscountFactors**: provides *natural cubic spline* interpolation on discount factors.
* **CompositeInterpolation**: provides support for different interpolation methods for: (1) extrapolation before first data point (`before_first`), (2) interpolation between the first and last point (`inner`), (3) extrapolation after last data point (`after_last`).

For *Interpolation Methods*, the field `parameters_id` holds the number of days between `dt_observation` and the maturity of the observed yield, following the curve's day count convention, which must be given in advance, when creating an instance of the curve. The field `parameters_values` holds the yield values for each maturity provided in `parameters_id`. All yields must be anual based, and must also be given in advance, when creating the instance of the curve.

**Term Structure Models**

* **NelsonSiegel**: term structure model based on *Nelson, C.R., and A.F. Siegel (1987), Parsimonious Modeling of Yield Curve, The Journal of Business, 60, 473-489*.
* **Svensson**: term structure model based on *Svensson, L.E. (1994), Estimating and Interpreting Forward Interest Rates: Sweden 1992-1994, IMF Working Paper, WP/94/114*.

For *Term Structure Models*, the fields `parameters_id` and `parameters_values` hold the constants defined by each model, as described below. They must be given in advance, when creating the instance of the curve.

For **NelsonSiegel** method, the array `parameters_values` holds the following parameters from the model:
* **beta1** = parameters_values[1] , parameters_id[1] = 1
* **beta2** = parameters_values[2] , parameters_id[2] = 2
* **beta3** = parameters_values[3] , parameters_id[3] = 3
* **lambda** = parameters_values[4], parameters_id[4] = 4

For **Svensson** method, the array `parameters_values` hold the following parameters from the model:
* **beta1** = parameters_values[1] , parameters_id[1] = 1
* **beta2** = parameters_values[2] , parameters_id[2] = 2
* **beta3** = parameters_values[3] , parameters_id[3] = 3
* **beta4** = parameters_values[4] , parameters_id[4] = 4
* **lambda1** = parameters_values[5] , parameters_id[5] = 5
* **lambda2** = parameters_values[6] , parameters_id[6] = 6

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

## Motivation for current design

By sharing the same data structure for *Interpolation Methods* and *Term Structure Models*, this package provides a *database-friendly* way to store curve data. Since only the raw curve data is stored on `IRCurve` data structure, there's a minimal storage requirement in order to track historical data about curves. For the same reason, and given Julia's high speed, it's possible to load many instances of curves on memory and perform fast valuation of Fixed Income contracts.

## Usage

```julia
using InterestRates

# First, create a curve instance.

vert_x = [11, 15, 19, 23] # for interpolation methods, represents the days to maturity
vert_y = [0.10, 0.15, 0.20, 0.19] # yield values

dt_curve = Date(2015,08,03)

mycurve = InterestRates.IRCurve("dummy-simple-linear", InterestRates.Actual365(),
	InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,
	vert_x, vert_y)

# yield for a given maturity date
y = zero_rate(mycurve, Date(2015,10,10))

# forward rate between two future dates
fy = forward_rate(mycurve, Date(2015,12,12), Date(2016, 02, 10))

# Discount factor for a given maturity date
df = discountfactor(mycurve, Date(2015,10,10))

# Effective Rate Factor for a given maturity
erf = ERF(mycurve, Date(2015,10,10))

# Effective Rate for a given maturity
er = ER(mycurve, Date(2015,10,10))
```

See `runtests.jl` for more examples.

## Alternative Libraries

* *Ito.jl* : https://github.com/aviks/Ito.jl
* *FinancialMarkets.jl* : https://github.com/imanuelcostigan/FinancialMarkets.jl
