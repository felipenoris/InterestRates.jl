
# YearFraction API

@inline value(yf::YearFraction) = yf.val
yearfraction(conv::DayCountConvention, day_count::Number) = YearFraction(day_count / daysperyear(conv))
yearfraction(conv::DayCountConvention, date_start::Date, date_end::Date) = yearfraction(conv, daycount(conv, date_start, date_end))
yearfraction(curve::AbstractIRCurve, maturity::Date) = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity)

yearfractionvalue(yf::YearFraction) = value(yf)
yearfractionvalue(args...) = value(yearfraction(args...)) # old yearfraction behavior

function Base.zero(yf::YearFraction{T}) where {T}
    YearFraction(zero(T))
end

Base.:(==)(y1::YearFraction, y2::YearFraction) = value(y1) == value(y2)
Base.isless(y1::YearFraction, y2::YearFraction) = value(y1) < value(y2)

# DayCountConvention

Base.:(==)(d1::BDays252, d2::BDays252) = d1.hc == d2.hc
Base.hash(d::BDays252) = 1 + hash(d.hc)

daycount(conv::BDays252, date_start::Date, date_end::Date) = BusinessDays.bdayscount(conv.hc, date_start, date_end)
daycount(::Actual360, date_start::Date, date_end::Date) = Int(Dates.value(date_end - date_start))
daycount(::Actual365, date_start::Date, date_end::Date) = Int(Dates.value(date_end - date_start))
function daycount(::Thirty360, date_start::Date, date_end::Date)
    Y = Dates.year(date_end) - Dates.year(date_start)
    M = Dates.month(date_end) - Dates.month(date_start)

    d1 = Dates.day(date_start)
    d2 = Dates.day(date_end)
    if d1 >= 30
        d1 = 30
        if d2 >= 30
            d2 = 30
        end
    end
    D = d2-d1

    return 360Y + 30M + D
end

advancedays(conv::BDays252, date_start::Date, daycount::Int) = BusinessDays.advancebdays(conv.hc, date_start, daycount)
advancedays(::Actual360, date_start::Date, daycount::Int) = date_start + Day(daycount)
advancedays(::Actual365, date_start::Date, daycount::Int) = date_start + Day(daycount)
advancedays(::Thirty360, date_start::Date, daycount::Int) = date_start + Day(daycount)

function advancedays(conv::DayCountConvention, date_start::Date, daycount_vec::Vector{Int})
    l = length(daycount_vec)
    result = Vector{Date}(undef, l)
    for i in 1:l
        @inbounds result[i] = advancedays(conv, date_start, daycount_vec[i])
    end
    return result
end

advancedays(curve::AbstractIRCurve, daycount) = advancedays(curve_get_daycount(curve), curve_get_date(curve), daycount)

daysperyear(::BDays252) = 252
daysperyear(::Actual360) = 360
daysperyear(::Actual365) = 365
daysperyear(::Thirty360) = 360

function days_to_maturity(curve::AbstractIRCurve, maturity::Date)
    d = daycount(curve_get_daycount(curve), curve_get_date(curve), maturity)
    @assert d >= 0 "Maturity date $(maturity) should be greater than curve observation date $(curve_get_date(curve))"
    return d
end

function days_to_maturity(curve::AbstractIRCurve, maturity::YearFraction)
    return value(maturity) * daysperyear(curve_get_daycount(curve))
end
