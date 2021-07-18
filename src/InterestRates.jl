
module InterestRates

import BusinessDays
using Dates

export
    ERF, ER, discountfactor, zero_rate, forward_rate,
    ERF_to_rate, discountfactor_to_rate,
    isnullcurve

include("api.jl")
include("splines.jl")
include("types.jl")
include("nullcurve.jl")
include("composed_curves.jl")
include("daycount.jl")
include("discount.jl")
include("bufferedcurve.jl")
include("curvemap.jl")
include("dailydatesrange.jl")

forward_rate(curve::AbstractIRCurve, forward_date::Date, maturity::Date) = ERF_to_rate(curve, ERF(curve, forward_date, maturity), yearfraction(curve_get_daycount(curve), forward_date, maturity))
forward_rate(curve::AbstractIRCurve, forward_date::YearFraction, maturity::YearFraction) = ERF_to_rate(curve, ERF(curve, forward_date, maturity), YearFraction(value(maturity) - value(forward_date)))

# Let's use the curve's method to multiple-dispatch. Ugly methods _zero_rate are not exported.
zero_rate(curve::AbstractIRCurve, maturity::Date) = _zero_rate(curve_get_method(curve), curve, maturity)
zero_rate(curve::AbstractIRCurve, maturity::YearFraction) = _zero_rate(curve_get_method(curve), curve, maturity)
zero_rate(curve::AbstractIRCurve, maturity_vec::Vector{Date}) = _zero_rate(curve_get_method(curve), curve, maturity_vec)

include("methods.jl") # implements various zero_rate() methods for each CurveMethod

end # module InterestRates
