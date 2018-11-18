
Base.:(==)(i1::CompositeInterpolation, i2::CompositeInterpolation) = i1.before_first == i2.before_first && i1.inner == i2.inner && i1.after_last == i2.after_last
Base.hash(i::CompositeInterpolation) = 1 + hash(i.before_first) + hash(i.inner) + hash(i.after_last)

# Curve methods implementation

_zero_rate(method::METHOD, curve::AbstractIRCurve, maturity::Date) where {METHOD<:RateInterpolation} = _zero_rate(method, curve_get_dtm(curve), curve_get_zero_rates(curve), days_to_maturity(curve, maturity))

function _zero_rate(comp::CompositeInterpolation, curve::AbstractIRCurve, maturity::Date)
    dtm = days_to_maturity(curve, maturity)

    if dtm < curve_get_dtm(curve)[1]
        return _zero_rate(comp.before_first, curve, maturity)
    elseif dtm > curve_get_dtm(curve)[end]
        return _zero_rate(comp.after_last, curve, maturity)
    else
        return _zero_rate(comp.inner, curve, maturity)
    end
end

# Returns tuple (index_a, index_b) for input vector x
# for interpolands on linear interpolation on point x_out
function _interpolationpoints(x::Vector{T}, x_out::T) where {T}
    local index_a::Int
    local index_b::Int

    if x_out <= x[1]
        # Interpolation point is before first vertice
        # Slope will be determined by the 1st and 2nd vertices
        index_a = 1
        index_b = 2
    elseif x_out >= x[end]
        # Interpolation point is after last vertice
        # Slope will be determined by the last and last-1 vertices
        index_b = length(x)
        index_a = index_b - 1
    else
        # Inner point
        index_a =  findlast(a -> a < x_out, x) # last element before x_out on x
        index_b = findfirst(b -> b >=  x_out, x) # first element after x_out on x
    end

    return index_a, index_b
end

# Perform Linear interpolation. Slope is determined by points (Xa, Ya) and (Xb, Yb).
# Interpolation occurs on point (x_out, returnvalue)
_linearinterp(Xa::TX, Ya::TY, Xb::TX, Yb::TY, x_out::TX) where {TX, TY} = (x_out - Xa) * (Yb - Ya) / (Xb - Xa) + Ya

# Linear interpolation of zero_rates
function _zero_rate(::Linear, x::Vector{Int}, y::Vector{Float64}, x_out::Int)
    # If this curve has only 1 vertice, this will be a flat curve
    if length(x) == 1
        return y[1]
    end

    index_a, index_b = _interpolationpoints(x, x_out)
    return _linearinterp(x[index_a], y[index_a], x[index_b], y[index_b], x_out)
end

# Step Function
function _zero_rate(::StepFunction, x::Vector{Int}, y::Vector{Float64}, x_out::Int)
    # If this curve has only 1 vertice, this will be a flat curve
    if length(x) == 1
        return y[1]
    end

    if x_out <= x[1]
        # Interpolation point is before first vertice
        # The result will be extrapolated using the first vertice zero_rate
        return y[1]
    elseif x_out >= x[end]
        # Interpolation point is after last vertice
        # The result will be extrapolated using the last vertice zero_rate
        return y[end]
    else
        # Inner point
        return y[findlast(a -> a <= x_out, x)] # last element before x_out on x
    end
end

# Flat Forward is linear interpolation on the log of discountfactors
# Maybe not useful for SimpleCompounding curves.
function _zero_rate(::FlatForward, curve::AbstractIRCurve, maturity::Date)
    # If this curve has only 1 vertice, this will be a flat curve
    if length(curve_get_zero_rates(curve)) == 1
        return curve_get_zero_rates(curve)[1]
    end

    x_out = days_to_maturity(curve, maturity)
    curve_dtm = curve_get_dtm(curve)
    curve_zero_rates = curve_get_zero_rates(curve)
    index_a, index_b = _interpolationpoints(curve_dtm, x_out)
    Xa = curve_dtm[index_a]
    Ya = curve_zero_rates[index_a]
    Xb = curve_dtm[index_b]
    Yb = curve_zero_rates[index_b]

    _daysperyear_ = daysperyear(curve_get_daycount(curve))
    year_fraction_a = Xa / _daysperyear_
    logPa = log(discountfactor(curve_get_compounding(curve), Ya, year_fraction_a))

    year_fraction_b = Xb / _daysperyear_
    logPb = log(discountfactor(curve_get_compounding(curve), Yb, year_fraction_b))

    year_fraction_x = x_out / _daysperyear_
    logPx = _linearinterp(year_fraction_a, logPa, year_fraction_b, logPb, year_fraction_x)

    return discountfactor_to_rate(curve_get_compounding(curve), exp(logPx), year_fraction_x)
end

function _zero_rate(::NelsonSiegel, curve::AbstractIRCurve, maturity::Date)

    # beta1 = param[1]
    # beta2 = param[2]
    # beta3 = param[3]
    # lambda = param[4]

    param = curve_get_model_parameters(curve)
    t = yearfraction(curve, maturity)
    _exp_lambda_t_ = exp(-param[4]*t)
    F_beta2 = (1.0 - _exp_lambda_t_) / (param[4]*t)

    return param[1] + param[2]*F_beta2 + param[3]*(F_beta2 - _exp_lambda_t_)
end

function _zero_rate(::Svensson, curve::AbstractIRCurve, maturity::Date)

    # beta1 = param[1]
    # beta2 = param[2]
    # beta3 = param[3]
    # beta4 = param[4]
    # lambda1 = param[5]
    # lambda2 = param[6]

    param = curve_get_model_parameters(curve)
    t = yearfraction(curve, maturity)
    _exp_lambda1_t_ = exp(-param[5]*t)
    _exp_lambda2_t_ = exp(-param[6]*t)
    F_beta2 = (1.0 - _exp_lambda1_t_) / (param[5]*t)

    return param[1] + param[2]*F_beta2 + param[3]*(F_beta2 - _exp_lambda1_t_) +
            param[4]*( (1.0 - _exp_lambda2_t_)/(param[6]*t) - _exp_lambda2_t_)
end

function _zero_rate(method::CubicSplineOnRates, curve::AbstractIRCurve, maturity::Date)
    sp = curve_get_spline_fit_on_rates(curve)
    return splineint(sp, days_to_maturity(curve, maturity))
end

function _zero_rate(::CubicSplineOnRates, curve::AbstractIRCurve, maturity_vec::Vector{Date})
    sp = curve_get_spline_fit_on_rates(curve)

    l = length(maturity_vec)
    rates = Vector{Float64}(undef, l)

    for i in 1:l
        @inbounds dtm = days_to_maturity(curve, maturity_vec[i])
        @inbounds rates[i] = splineint(sp, dtm)
    end
    return rates
end

function _zero_rate(::CubicSplineOnDiscountFactors, curve::AbstractIRCurve, maturity::Date)
    sp = curve_get_spline_fit_on_discount_factors(curve)
    yf_maturity = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity)
    result_discount_factor = splineint(sp, yf_maturity)
    return discountfactor_to_rate(curve_get_compounding(curve), result_discount_factor, yf_maturity)
end

function _zero_rate(::CubicSplineOnDiscountFactors, curve::AbstractIRCurve, maturity_vec::Vector{Date})
    sp = curve_get_spline_fit_on_discount_factors(curve)
    mat_vec_len = length(maturity_vec)

    yf_maturity_vec = Vector{Float64}(undef, mat_vec_len)
    for i in 1:mat_vec_len
        @inbounds yf_maturity_vec[i] = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity_vec[i])
    end

    return discountfactor_to_rate(curve_get_compounding(curve), splineint(sp, yf_maturity_vec), yf_maturity_vec)
end

# Generate vector functions
for elty in (:FlatForward, :CompositeInterpolation, :StepFunction, :Linear, :NelsonSiegel, :Svensson)
    @eval begin
        function _zero_rate(m::$elty, curve::AbstractIRCurve, maturity_vec::Vector{Date})
            l = length(maturity_vec)
            rates = Vector{Float64}(undef, l)
            for i = 1:l
                @inbounds rates[i] = _zero_rate(m, curve, maturity_vec[i])
            end
        return rates
        end
    end
end
