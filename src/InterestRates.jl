
module InterestRates

using BusinessDays
using Dates

export
    ERF, ER, discountfactor, zero_rate, forward_rate,
    ERF_to_rate, discountfactor_to_rate,
    isnullcurve

include("splines.jl")
include("types.jl")
include("nullcurve.jl")
include("composite.jl")
include("daycount.jl")
include("discount.jl")
include("bufferedcurve.jl")

forward_rate(curve::AbstractIRCurve, forward_date::Date, maturity::Date) = ERF_to_rate(curve, ERF(curve, forward_date, maturity), yearfraction(curve_get_daycount(curve), forward_date, maturity))

# Let's use the curve's method to multiple-dispatch. Ugly methods _zero_rate are not exported.
zero_rate(curve::AbstractIRCurve, maturity::Date) = _zero_rate(curve_get_method(curve), curve, maturity)
zero_rate(curve::AbstractIRCurve, maturity_vec::Vector{Date}) = _zero_rate(curve_get_method(curve), curve, maturity_vec)

include("methods.jl") # implements various zero_rate() methods for each CurveMethod

end # module InterestRates
