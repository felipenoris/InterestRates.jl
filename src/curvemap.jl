
"""
Acceps a map function that is applied to the `zero_rate` of the curve.

The map function `f` takes the form `f(rate, maturity)` with the following arguments:

    * `rate` is the retult of `zero_rate` applied to underlying curve for `maturity`.

    * `maturity` is the requested zero rate maturity.

The `zero_rate` for a `CurveMap` is implemented as:

```julia
zero_rate(curve::CurveMap, maturity::Date) = curve.f(zero_rate(curve.curve, maturity), maturity)
```

# Example

```julia
vert_x = [11, 15, 19, 23]
vert_y = [0.09, 0.14, 0.19, 0.18] # yield values 9%, 14%, 19%, 18%

# parallel shock of 1%
function map_parallel_1pct(rate, maturity)
    return rate + 0.01
end

dt_curve = Date(2015,08,03)

curve_map = InterestRates.CurveMap("mapped-curve", map_parallel_1pct, InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.Actual360(),
    InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
    vert_x, vert_y))

# will report zero rate as 10% for maturity 11 days
zero_rate(curve_map, dt_curve + Dates.Day(11)) ≈ 0.1
```
"""
struct CurveMap{M, C<:AbstractIRCurve{M}, F<:Function} <: AbstractIRCurve{M}
    name::String
    f::F
    curve::C
end

for fun in (:curve_get_daycount, :curve_get_compounding, :curve_get_method, :curve_get_date, :curve_get_dtm, :curve_get_zero_rates, :curve_get_model_parameters, :curve_get_spline_fit_on_rates, :curve_get_spline_fit_on_discount_factors)
    @eval begin
        ($fun)(curve::CurveMap) = ($fun)(curve.curve)
    end
end

zero_rate(curve::CurveMap, maturity::Date) = curve.f(zero_rate(curve.curve, maturity), maturity)
curve_get_name(curve::CurveMap) = curve.name
