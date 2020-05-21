
Base.firstindex(::DailyDatesRange) = 1
Base.isempty(::DailyDatesRange) = false # has at least one item
Base.length(d::DailyDatesRange) = daycount(d.daycountconvention, d.startdate, d.enddate) + 1
Base.issorted(d::DailyDatesRange) = isascending(d) || length(d) == 1
Base.minimum(dd::DailyDatesRange) = dd.startdate
Base.maximum(dd::DailyDatesRange) = dd.enddate

function Base.in(date::Date, dd::DailyDatesRange{A, T}) :: Bool where {A,T<:Union{Actual360, Actual365}}
    return dd.startdate <= date <= dd.enddate
end

function Base.in(date::Date, dd::DailyDatesRange{A, BDays252}) :: Bool where {A}
    return (dd.startdate <= date <= dd.enddate) && BusinessDays.isbday(dd.daycountconvention.hc, date)
end

yearfraction(d::DailyDatesRange) = yearfraction(d.daycountconvention, 1)
yearfractionvalue(d::DailyDatesRange) = yearfractionvalue(yearfraction(d))

function Base.getindex(d::DailyDatesRange{true}, i::Integer) :: Dates.Date
    result = advancedays(d.daycountconvention, d.startdate, i - 1)
    @assert result <= d.enddate "Index $i out of bounds."
    return result
end

function Base.getindex(d::DailyDatesRange{false}, i::Integer) :: Dates.Date
    result = advancedays(d.daycountconvention, d.enddate, -(i - 1))
    @assert result >= d.startdate
    return result
end

function isascending(::DailyDatesRange{A}) :: Bool where {A}
    A
end

Base.reverse(dd::DailyDatesRange) = DailyDatesRange(dd.startdate, dd.enddate, dd.daycountconvention, !isascending(dd))
Base.show(io::IO, dd::DailyDatesRange) = print(io, "DailyDatesRange($(dd.startdate), $(dd.enddate), $(dd.daycountconvention))")

Base.iterate(dd::DailyDatesRange{true}) = (dd.startdate, dd.startdate)
Base.iterate(dd::DailyDatesRange{false}) = (dd.enddate, dd.enddate)

function Base.iterate(dd::DailyDatesRange{true}, current_date::Date)
    next_date = advancedays(dd.daycountconvention, current_date, 1)
    if next_date > dd.enddate
        return nothing
    else
        return (next_date, next_date)
    end
end

function Base.iterate(dd::DailyDatesRange{false}, current_date::Date)
    next_date = advancedays(dd.daycountconvention, current_date, -1)
    if next_date < dd.startdate
        return nothing
    else
        return (next_date, next_date)
    end
end
