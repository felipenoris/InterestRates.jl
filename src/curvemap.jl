
"""
Acceps a map function that is applied to the `zero_rate` of the curve.

The `zero_rate` for a `CurveMap` is implemented as:

```julia
zero_rate(curve::CurveMap, maturity::Date) = curve.f(zero_rate(curve.curve))
```

# Example

```julia

```
"""
struct CurveMap{M, C<:AbstractIRCurve{M}, F<:Function} <: AbstractIRCurve{M}
    f::F
    curve::C
end

for fun in (:curve_get_name, :curve_get_daycount, :curve_get_compounding, :curve_get_method, :curve_get_date, :curve_get_dtm, :curve_get_zero_rates, :curve_get_model_parameters, :curve_get_spline_fit_on_rates, :curve_get_spline_fit_on_discount_factors)
    @eval begin
        ($fun)(curve::CurveMap) = ($fun)(curve.curve)
    end
end

zero_rate(curve::CurveMap, maturity::Date) = curve.f(zero_rate(curve.curve, maturity))
