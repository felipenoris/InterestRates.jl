
Base.:(==)(d1::BDays252, d2::BDays252) = d1.hc == d2.hc
Base.hash(d::BDays252) = 1 + hash(d.hc)

daycount(conv::BDays252, date_start::Date, date_end::Date) = bdayscount(conv.hc, date_start, date_end)
daycount(::Actual360, date_start::Date, date_end::Date) = Int(Dates.value(date_end - date_start))
daycount(::Actual365, date_start::Date, date_end::Date) = Int(Dates.value(date_end - date_start))

advancedays(conv::BDays252, date_start::Date, daycount::Int) = advancebdays(conv.hc, date_start, daycount)
advancedays(::Actual360, date_start::Date, daycount::Int) = date_start + Day(daycount)
advancedays(::Actual365, date_start::Date, daycount::Int) = date_start + Day(daycount)

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

yearfraction(conv::DayCountConvention, date_start::Date, date_end::Date) = daycount(conv, date_start, date_end) / daysperyear(conv)
yearfraction(curve::AbstractIRCurve, maturity::Date) = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity)

function days_to_maturity(curve::AbstractIRCurve, maturity::Date)
    d = daycount(curve_get_daycount(curve), curve_get_date(curve), maturity)
    @assert d >= 0 "Maturity date $(maturity) should be greater than curve observation date $(curve_get_date(curve))"
    return d
end
