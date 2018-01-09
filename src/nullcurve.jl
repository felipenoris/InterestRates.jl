### Null curve ###

struct NullIRCurve <: AbstractIRCurve end

ERF(curve::NullIRCurve, maturity::Date) = 1.0
ER(curve::NullIRCurve, maturity::Date) = 0.0
discountfactor(curve::NullIRCurve, maturity::Date) = 1.0
curve_get_name(::NullIRCurve) = "NullCurve"
curve_get_date(::NullIRCurve) = error("Date for NullCurve is not defined.")
isnullcurve(curve::NullIRCurve) = true
isnullcurve(curve::AbstractIRCurve) = false
forward_rate(curve::NullIRCurve, forward_date::Date, maturity::Date) = 0.0
zero_rate(curve::NullIRCurve, maturity::Date) = 0.0
zero_rate(curve::NullIRCurve, maturity_vec::Vector{Date}) = zeros(length(maturity_vec))
