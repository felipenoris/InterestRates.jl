### Composite Curve ###

mutable struct CompositeIRCurve <: AbstractIRCurve
    date::Date
    list::Vector{AbstractIRCurve}

    function CompositeIRCurve(curve_tuple::AbstractIRCurve...)
        @assert !isempty(curve_tuple) "Empty list of curves for CompositeIRCurve"
        date = curve_get_date(curve_tuple[1])
        len = length(curve_tuple)
        if len > 1
            for i in 2:len
                @assert date == curve_get_date(curve_tuple[i]) "All curve dates should match for CompositeIRCurve"
            end
        end

        list = Vector{AbstractIRCurve}(undef, len)
        for i in 1:len
            @inbounds list[i] = curve_tuple[i]
        end

        new(date, list)
    end
end

curve_get_date(c::CompositeIRCurve) = c.date

function ERF(curve::CompositeIRCurve, maturity::Date)
    local _erf::Float64 = 1.0
    for c in curve.list
        _erf *= ERF(c, maturity)
    end
    return _erf
end

# Unoptimized vector function for ERF
function ERF(curve::CompositeIRCurve, maturity_vec::Vector{Date})
    len = length(maturity_vec)
    result = Vector{Float64}(undef, len)
    for i in 1:len
        @inbounds result[i] = ERF(curve, maturity_vec[i])
    end
    return result
end

# Unoptimized vector function for discountfactor
function discountfactor(curve::CompositeIRCurve, maturity_vec::Vector{Date})
    len = length(maturity_vec)
    result = Vector{Float64}(undef, len)
    for i in 1:len
        @inbounds result[i] = discountfactor(curve, maturity_vec[i])
    end
    return result
end

ERF_to_rate(curve::CompositeIRCurve, ERF::Float64, t::Float64) = error("Function not available for CompositeIRCurve")
forward_rate(curve::CompositeIRCurve, forward_date::Date, maturity::Date) = error("Function not available for CompositeIRCurve")
zero_rate(curve::CompositeIRCurve, maturity::Date) = error("Function not available for CompositeIRCurve")
zero_rate(curve::CompositeIRCurve, maturity_vec::Vector{Date}) = error("Function not available for CompositeIRCurve")
