
daycount(conv::BDays252, date_start::Date, date_end::Date) = Int(Dates.value(bdays(conv.hc, date_start, date_end)))
daycount(::Actual360, date_start::Date, date_end::Date) = Int(Dates.value(date_end - date_start))
daycount(::Actual365, date_start::Date, date_end::Date) = Int(Dates.value(date_end - date_start))

# Thirty360 daycount functions adapted from QuantLib.jl and Ito.jl
function daycount(::BondThirty360, d_start::Date, d_end::Date)
  dd1 = day(d_start)
  dd2 = day(d_end)

  mm1 = month(d_start)
  mm2 = month(d_end)

  yy1 = year(d_start)
  yy2 = year(d_end)

  if dd2 == 31 && dd1 < 30
    dd2 = 1
    mm2 += 1
  end

  return 360.0 * (yy2 - yy1) + 30.0 * (mm2 - mm1 - 1) + max(0, 30 - dd1) + min(30, dd2)
end

function daycount(::EuroBondThirty360, d_start::Date, d_end::Date)
  dd1 = day(d_start)
  dd2 = day(d_end)

  mm1 = month(d_start)
  mm2 = month(d_end)

  yy1 = year(d_start)
  yy2 = year(d_end)

  return 360.0 * (yy2 - yy1) + 30.0 * (mm2 - mm1 - 1) + max(0, 30 - dd1) + min(30, dd2)
end

function daycount(::ItalianThirty360,  d_start::Date,  d_end::Date)
    dd1 = day(d_start)
    dd2 = day(d_end)
    mm1 = month(d_start)
    mm2 = month(d_end)
    yy1 = year(d_start)
    yy2 = year(d_end)

    if (mm1 == 2 && dd1 > 27) 
        dd1 = 30
    end
    if (mm2 == 2 && dd2 > 27) 
        dd2 = 30
    end

    return 360*(yy2-yy1) + 30*(mm2-mm1-1) + max(0, 30-dd1) + min(30, dd2)
end

advancedays(conv::BDays252, date_start::Date, daycount::Int) = advancebdays(conv.hc, date_start, daycount)
advancedays(::Actual360, date_start::Date, daycount::Int) = date_start + Day(daycount)
advancedays(::Actual365, date_start::Date, daycount::Int) = date_start + Day(daycount)

function advancedays(conv::DayCountConvention, date_start::Date, daycount_vec::Vector{Int})
	l = length(daycount_vec)
	result = Array{Date}(l)
	for i in 1:l
		result[i] = advancedays(conv, date_start, daycount_vec[i])
	end
	return result
end

advancedays(curve::AbstractIRCurve, daycount) = advancedays(curve_get_daycount(curve), curve_get_date(curve), daycount)

daysperyear(::BDays252) = 252
daysperyear(::Actual360) = 360
daysperyear(::Actual365) = 365
daysperyear(::Thirty360) = 360

yearfraction(conv::DayCountConvention, date_start::Date, date_end::Date) = daycount(conv, date_start, date_end) / daysperyear(conv)
yearfraction(curve::AbstractIRCurve, maturity::Date) = yearfraction(curve_get_daycount(curve), curve_get_date(curve), maturity)

function days_to_maturity(curve::AbstractIRCurve, maturity::Date)
	d = daycount(curve_get_daycount(curve), curve_get_date(curve), maturity)
	@assert d >= 0 "Maturity date $(maturity) should be greater than curve observation date $(curve_get_date(curve))"
	return d
end
