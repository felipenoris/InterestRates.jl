
# API Reference

## Types

```@docs
InterestRates.DayCountConvention
InterestRates.DailyDatesRange
InterestRates.CompoundingType
InterestRates.CurveMethod
InterestRates.AbstractIRCurve
```

## AbstractIRCurve API

```
InterestRates.curve_get_name
InterestRates.curve_get_dtm
InterestRates.curve_get_zero_rates
InterestRates.curve_get_model_parameters
InterestRates.curve_get_date
InterestRates.curve_get_daycount
InterestRates.curve_get_method
InterestRates.curve_get_compounding
```

## Curve Methods

```@docs
InterestRates.zero_rate
InterestRates.forward_rate
InterestRates.discountfactor
```
