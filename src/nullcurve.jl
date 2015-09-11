### Null curve ###

type NullIRCurve <: AbstractIRCurve end

ERF(curve::NullIRCurve, maturity::Date) = 1.0
ER(curve::NullIRCurve, maturity::Date) = 0.0
discountfactor(curve::NullIRCurve, maturity::Date) = 1.0
getcurvename(::NullIRCurve) = "NullCurve"
getcurvedate(::NullIRCurve) = error("Method getcurvedate not defined for NullCurve.")
isnullcurve(curve::NullIRCurve) = true
isnullcurve(curve::AbstractIRCurve) = false
forward_rate(curve::NullIRCurve, forward_date::Date, maturity::Date) = 0.0
zero_rate(curve::NullIRCurve, maturity::Date) = 0.0
zero_rate(curve::NullIRCurve, maturity_vec::Vector{Date}) = zeros(length(maturity_vec))
