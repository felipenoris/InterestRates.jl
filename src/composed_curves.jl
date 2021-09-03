
mutable struct ComposeFactorCurve{F<:Function, IRA<:AbstractIRCurve, IRB<:AbstractIRCurve} <: AbstractIRCurve{NullMethod}
    name::String
    date::Date
    op::F
    curve_a::IRA
    curve_b::IRB
    daycount::DayCountConvention
    compounding::CompoundingType

    function ComposeFactorCurve(
                name::AbstractString,
                date::Date,
                op::F,
                curve_a::IRA,
                curve_b::IRB,
                daycount::DayCountConvention,
                compounding::CompoundingType
            ) where {F<:Function, IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

        @assert curve_get_date(curve_a) == date && curve_get_date(curve_b) == date "curve_a and curve_b should have the same dates"
        return new{F, IRA, IRB}(name, date, op, curve_a, curve_b, daycount, compounding)
    end
end

function ComposeFactorCurve(
                date::Date,
                op::F,
                curve_a::IRA,
                curve_b::IRB,
                daycount::DayCountConvention,
                compounding::CompoundingType
            ) where {F<:Function, IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

    ComposeFactorCurve("", date, op, curve_a, curve_b, daycount, compounding)
end


"""
    ComposeProdFactorCurve(
            [name],
            curve_a::IRA,
            curve_b::IRB,
            daycount::DayCountConvention,
            compounding::CompoundingType
        ) where {IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

Creates a curve that is composed by the discount factors of `curve_a * curve_b`.
The resulting curve will produce zero rates based on `daycount` and `compounding` conventions.
"""
function ComposeProdFactorCurve(
            curve_a::IRA,
            curve_b::IRB,
            daycount::DayCountConvention,
            compounding::CompoundingType
        ) where {IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

    @nospecialize daycount compounding
    return ComposeFactorCurve(curve_get_date(curve_a), *, curve_a, curve_b, daycount, compounding)
end

function ComposeProdFactorCurve(
            name::AbstractString,
            curve_a::IRA,
            curve_b::IRB,
            daycount::DayCountConvention,
            compounding::CompoundingType
        ) where {IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

    @nospecialize daycount compounding
    return ComposeFactorCurve(name, curve_get_date(curve_a), *, curve_a, curve_b, daycount, compounding)
end

"""
    ComposeDivFactorCurve(
            [name],
            curve_a::IRA,
            curve_b::IRB,
            daycount::DayCountConvention,
            compounding::CompoundingType
        ) where {IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}


Creates a curve that is composed by the discount factors of `curve_a / curve_b`.
The resulting curve will produce zero rates based on `daycount` and `compounding` conventions.
"""
function ComposeDivFactorCurve(
            curve_a::IRA,
            curve_b::IRB,
            daycount::DayCountConvention,
            compounding::CompoundingType
        ) where {IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

    @nospecialize daycount compounding
    return ComposeFactorCurve(curve_get_date(curve_a), /, curve_a, curve_b, daycount, compounding)
end

function ComposeDivFactorCurve(
            name::AbstractString,
            curve_a::IRA,
            curve_b::IRB,
            daycount::DayCountConvention,
            compounding::CompoundingType
        ) where {IRA<:AbstractIRCurve, IRB<:AbstractIRCurve}

    @nospecialize daycount compounding
    return ComposeFactorCurve(name, curve_get_date(curve_a), /, curve_a, curve_b, daycount, compounding)
end

function curve_get_name(c::ComposeFactorCurve)
    @nospecialize c
    return c.name
end

function curve_get_date(c::ComposeFactorCurve)
    @nospecialize c
    return c.date
end

function curve_get_daycount(c::ComposeFactorCurve)
    @nospecialize c
    return c.daycount
end

function curve_get_compounding(c::ComposeFactorCurve)
    @nospecialize c
    return c.compounding
end

# using @eval instead of Union{Date, YearFraction} to avoid method ambiguity
for T in (:Date, :YearFraction)
    @eval begin
        function ERF(c::ComposeFactorCurve, maturity::$T)
            return c.op( ERF(c.curve_a, maturity), ERF(c.curve_b, maturity) )
        end

        function zero_rate(c::ComposeFactorCurve, maturity::$T)
            erf = ERF(c, maturity)
            ERF_to_rate(c, erf, maturity)
        end
    end
end

# Unoptimized vector function for ERF
function ERF(curve::ComposeFactorCurve, maturity_vec::Vector{Date})
    @nospecialize curve

    len = length(maturity_vec)
    result = Vector{Float64}(undef, len)
    for i in 1:len
        @inbounds result[i] = ERF(curve, maturity_vec[i])
    end
    return result
end

# Unoptimized vector function for discountfactor
function discountfactor(curve::ComposeFactorCurve, maturity_vec::Vector{Date})
    @nospecialize curve

    len = length(maturity_vec)
    result = Vector{Float64}(undef, len)
    for i in 1:len
        @inbounds result[i] = discountfactor(curve, maturity_vec[i])
    end
    return result
end
