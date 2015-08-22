# InterestRates.jl [![Build Status](https://travis-ci.org/felipenoris/InterestRates.jl.svg?branch=master)](https://travis-ci.org/felipenoris/InterestRates.jl) [![Coverage Status](https://coveralls.io/repos/felipenoris/InterestRates.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/felipenoris/InterestRates.jl?branch=master) [![codecov.io](http://codecov.io/github/felipenoris/InterestRates.jl/coverage.svg?branch=master)](http://codecov.io/github/felipenoris/InterestRates.jl?branch=master)
Tools for **Term Structure of Interest Rates** calculation, aimed at the valuation of financial contracts, especially *Fixed Income* instruments.

**Installation**: 
```julia
julia> Pkg.clone("https://github.com/felipenoris/InterestRates.jl.git")
```
## Concept

A Term Structure of Interest Rates, also known as *zero-coupon curve*, is a function `f(t) -> y` that maps a given maturity `t` onto the yield `y` of a bond that matures at `t` and pays no coupons (*zero-coupon bond*).

For instance, say the current price of a bond that pays exactly `10` in `1` year is `9.25`. If one buys that bond for the current price and holds it until the maturity of the contract, that investor will gain `0.75`, which represents `8.11%` of the original price. That means that the bond is currently priced with a yield of `8.11%` *per year*.

It's not possible to observe prices for each possible maturity. We can observe only a set of discrete data points of the yield curve. Therefore, in order to determine the entire term structure, one must choose an interpolation method, or a term structure model.

All yield curve calculation is built around a database-friendly data type: `IRCurve`.

```julia
type IRCurve <: AbstractIRCurve
	name::ASCIIString # curve name for reference
	daycount::DayCountConvention # convention on how to count number of days between dates
	compounding::CompoundingType # convention on how to convert an interest rates to a effective rate factor
	method::CurveMethod # see Curve Methods section
	dt_observation::Date # reference date for the curve data
	parameters_id::Vector{Int} # for interpolation methods, id stores days_to_maturity on curve's daycount convention.
	parameters_values::Vector{Float64}
#...
```

## Curve Methods

This package provide the following curve methods.

**Interpolation Methods**

* **Linear**: provides Linear Interpolation on rates.
* **FlatForward**: provides Flat Forward interpolation, which is implemented as a Linear Interpolation on discount factors.
* **StepFunction**: creates a step function around given data points
* **CubicSplineOnRates**: provides natural cubic spline interpolation on rates.
* **CubicSplineOnDiscountFactors**: provides natural cubic spline interpolation on discount factors.

**Term Structure Models**

* **NelsonSiegel**: term structure model based on *Nelson, C.R., and A.F. Siegel (1987), Parsimonious Modeling of Yield Curve, The Journal of Busi- ness, 60, 473-489.*.
* **Svensson**: term structure model based on *Svensson, L.E. (1994), Estimating and Interpreting Forward Interest Rates: Sweden 1992-1994, IMF Working Paper, WP/94/114.*.

For **NelsonSiegel** method, the array `parameters_values` holds the following parameters from the model:
* **beta1** = parameters_values[1]
* **beta2** = parameters_values[2]
* **beta3** = parameters_values[3]
* **lambda** = parameters_values[4]

For **Svensson** method, the array `parameters_values` hold the following parameters from the model:
* **beta1** = parameters_values[1]
* **beta2** = parameters_values[2]
* **beta3** = parameters_values[3]
* **beta4** = parameters_values[4]
* **lambda1** = parameters_values[5]
* **lambda2** = parameters_values[6]

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
df = y = discountfactor(mycurve, Date(2015,10,10))

# Effective Rate Factor for a given maturity
erf = ERF(mycurve, Date(2015,10,10))

# Effective Rate for a given maturity
er = ER(mycurve, Date(2015,10,10))
```
