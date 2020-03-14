
"""
    zero_rate(curve, maturity)

Returns the *zero-coupon* rate to `maturity`.
"""
function zero_rate end

"""
    forward_rate(curve, forward_date, maturity)

Returns the *forward rate* from a future date
`forward_date` to `maturity`.
"""
function forward_rate end

"""
    discountfactor(curve, maturity)
    discountfactor(curve, forward_date, maturity)

Returns the discount factor to `maturity`.
Or a forward discount factor from `forward_date` to `maturity`.
"""
function discountfactor end
