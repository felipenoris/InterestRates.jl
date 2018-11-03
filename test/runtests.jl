
# Tests for module InterestRates

using Test
using BusinessDays
using InterestRates
using Dates

BusinessDays.initcache(BusinessDays.Brazil())

vert_x = [11, 15, 19, 23]
vert_y = [0.10, 0.15, 0.20, 0.19]

dt_curve = Date(2015,08,03)

# Error testing
@test_throws AssertionError InterestRates.IRCurve("", InterestRates.Actual365(), InterestRates.ExponentialCompounding(),
    InterestRates.Linear(), dt_curve, [1, 2, 6, 5], [.1, .1, .1, .1])

@test_throws AssertionError InterestRates.IRCurve("", InterestRates.Actual365(), InterestRates.ExponentialCompounding(),
    InterestRates.Linear(), dt_curve, [1, 2, 3, 4], [.1, .1, .1])

@test_throws AssertionError InterestRates.IRCurve("", InterestRates.Actual365(), InterestRates.ExponentialCompounding(),
    InterestRates.Linear(), dt_curve, Vector{Int}() , [.1, .1, .1])

@test_throws AssertionError InterestRates.IRCurve("", InterestRates.Actual365(), InterestRates.ExponentialCompounding(),
    InterestRates.Linear(), dt_curve, Vector{Int}(undef, 1) , Vector{Float64}())

@test_throws AssertionError InterestRates.IRCurve("", InterestRates.Actual365(), InterestRates.ExponentialCompounding(),
    InterestRates.Linear(), dt_curve, Vector{Int}() , Vector{Float64}())

curve_b252_ec_lin = InterestRates.IRCurve("dummy-linear", InterestRates.BDays252(BusinessDays.Brazil()),
    InterestRates.ExponentialCompounding(), InterestRates.Linear(), dt_curve,
    vert_x, vert_y)

@test_throws AssertionError zero_rate(curve_b252_ec_lin, dt_curve - Dates.Day(10))

@test InterestRates.curve_get_name(curve_b252_ec_lin) == "dummy-linear"
@test InterestRates.curve_get_date(curve_b252_ec_lin) == dt_curve

# daycount equality
let
    x = InterestRates.BDays252(BusinessDays.Brazil())
    y = InterestRates.BDays252(BusinessDays.Brazil())
    @test x == y

    z = InterestRates.Actual360()
    @test x != z
    @test y != z

    @test hash(x) == hash(y)
    @test hash(x) != hash(z)
    @test hash(y) != hash(z)
end

# method equality
let
    @test InterestRates.Linear() == InterestRates.Linear()
    @test InterestRates.Linear() != InterestRates.FlatForward()
    @test InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward()) == InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward())
    @test InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward()) != InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.StepFunction())
    @test InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward()) != InterestRates.Linear()

    @test hash(InterestRates.Linear()) == hash(InterestRates.Linear())
    @test hash(InterestRates.Linear()) != hash(InterestRates.FlatForward())
    @test hash(InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward())) == hash(InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward()))
    @test hash(InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward())) != hash(InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.StepFunction()))
    @test hash(InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.FlatForward())) != hash(InterestRates.Linear())
end

maturity_2_days = advancebdays(BusinessDays.Brazil(), dt_curve, vert_x[1] + 2)
yrs = (vert_x[1] + 2) / 252.0
zero_rate_2_days = 0.125
disc_2_days = 1.0 / ( (1.0 + zero_rate_2_days)^yrs)
@test zero_rate_2_days ≈ zero_rate(curve_b252_ec_lin, maturity_2_days) # Linear interpolation
@test disc_2_days ≈ discountfactor(curve_b252_ec_lin, maturity_2_days)
@test zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, 11)) ≈ 0.10
@test_throws AssertionError zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, -4)) # maturity before curve date
@test zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, 11-4)) ≈ 0.05 # extrapolate before first vertice
@test zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, 23+4)) ≈ 0.18 # extrapolate after last vertice

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_b252_ec_lin, ERF(curve_b252_ec_lin, dt_maturity), InterestRates.yearfraction(curve_b252_ec_lin, dt_maturity)) ≈ zero_rate(curve_b252_ec_lin, dt_maturity)

curve_ac360_cont_ff = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.Actual360(),
    InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
    vert_x, vert_y)

@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(15)) ≈ 0.15
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19)) ≈ 0.20
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(23)) ≈ 0.19
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(16)) > 0.15
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(17)) < 0.20
@test forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) ≈ 0.2875 # forward_rate calculation on vertices
@test forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(13)) ≈ 0.2875 # forward_rate calculation on interpolated maturity
@test ERF(curve_ac360_cont_ff, dt_curve + Dates.Day(13)) ≈ 1.00466361875533 # ffwd interp on ERF

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_ac360_cont_ff, ERF(curve_ac360_cont_ff, dt_maturity), InterestRates.yearfraction(curve_ac360_cont_ff, dt_maturity)) ≈ zero_rate(curve_ac360_cont_ff, dt_maturity)
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(13)) ≈ 0.128846153846152 # ffwd interp as zero_rate
@test ERF(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ 1.00158458746737
@test forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ 0.1425000000000040
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(30)) ≈ 0.1789166666666680 # ffwd extrap after last vertice
@test forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(50), dt_curve + Dates.Day(51))
@test forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(50), dt_curve + Dates.Day(100))

@test forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) ≈ 0.2875
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(9)) ≈ 0.05833333333333 # ffwd extrap before first vertice

@test discountfactor(curve_ac360_cont_ff, dt_curve) == 1
@test isnan(ERF_to_rate(curve_ac360_cont_ff, 1.0, 0.0))

# Null curve tests
n_curve = InterestRates.NullIRCurve()
@test n_curve == InterestRates.NullIRCurve() # Should be singleton
@test ERF(n_curve, Date(2000,1,1)) == 1.0
@test ER(n_curve, Date(2000,1,1)) == 0.0
@test discountfactor(n_curve, Date(2000,1,1)) == 1.0
@test InterestRates.curve_get_name(n_curve) == "NullCurve"
@test isnullcurve(n_curve) == true
@test isnullcurve(curve_ac360_cont_ff) == false
@test forward_rate(n_curve, Date(2000,1,1), Date(2000,1,2)) == 0.0
@test zero_rate(n_curve, Date(2000,1,1)) == 0.0
@test zero_rate(n_curve, [Date(2000,1,1), Date(2000,1,2)]) == [ 0.0, 0.0 ]

# Tests for vector functions
dt_curve = Date(2015, 08, 07)
curve_ac365_simple_linear = InterestRates.IRCurve("dummy-simple-linear", InterestRates.Actual365(),
    InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,
    vert_x, vert_y)
mat_vec = [ Date(2015,08,17), Date(2015,08,18), Date(2015,08,19), Date(2015,08,20), Date(2015,08,21), Date(2015,08,22)]
@test zero_rate(curve_ac365_simple_linear, mat_vec) ≈ [0.0875,0.1,0.1125,0.1250,0.1375,0.15]
@test ERF(curve_ac365_simple_linear, mat_vec) ≈ [1.00239726027397, 1.00301369863014, 1.00369863013699, 1.00445205479452, 1.00527397260274, 1.00616438356164]
@test discountfactor(curve_ac365_simple_linear, mat_vec) ≈ [0.997608472839084, 0.996995356459984, 0.996314999317592, 0.995567678145244, 0.994753696259454, 0.993873383253914]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_ac365_simple_linear, ERF(curve_ac365_simple_linear, dt_maturity), InterestRates.yearfraction(curve_ac365_simple_linear, dt_maturity)) ≈ zero_rate(curve_ac365_simple_linear, dt_maturity)

comp = InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.StepFunction())
curve_ac365_simple_comp = InterestRates.IRCurve("dummy-simple-linear", InterestRates.Actual365(),
    InterestRates.SimpleCompounding(), comp, dt_curve,
    vert_x, vert_y)
@test zero_rate(curve_ac365_simple_comp, mat_vec) ≈ [0.1,0.1,0.1125,0.1250,0.1375,0.15]
@test zero_rate(curve_ac365_simple_comp, Date(2100,2,2)) ≈ 0.19

curve_step = InterestRates.IRCurve("step-curve", InterestRates.Actual365(),
    InterestRates.SimpleCompounding(), InterestRates.StepFunction(), dt_curve,
    vert_x, vert_y)
mat_vec = [ Date(2015,08,08), Date(2015,08,12), Date(2015,08,17), Date(2015,08,18), Date(2015,08,19),
    Date(2015,08,21), Date(2015,08,22), Date(2015,08,23), Date(2015,08,25), Date(2015,08,26),
    Date(2015,08,27), Date(2015,08,29), Date(2015,08,30), Date(2015,08,31), Date(2015,09,26)]

@test zero_rate(curve_step, mat_vec) ≈ [0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.15, 0.15, 0.15, 0.20, 0.20, 0.20, 0.19, 0.19, 0.19]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_step, ERF(curve_step, dt_maturity), InterestRates.yearfraction(curve_step, dt_maturity)) ≈ zero_rate(curve_step, dt_maturity)

# Nelson Siegel
dt_curve = Date(2015, 08, 11)
curve_NS = InterestRates.IRCurve("dummy-continuous-nelsonsiegel", InterestRates.Actual360(),
    InterestRates.ContinuousCompounding(), InterestRates.NelsonSiegel(), dt_curve,
    [0.1, 0.2, 0.3, 0.5])

mat_vec = [Date(2015,8,12), Date(2016,8,12)]
@test zero_rate(curve_NS, mat_vec) ≈ [0.300069315921728, 0.311522078457982]
@test discountfactor(curve_NS, mat_vec) ≈ [0.999166821408637, 0.727908844513432]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_NS, ERF(curve_NS, dt_maturity), InterestRates.yearfraction(curve_NS, dt_maturity)) ≈ zero_rate(curve_NS, dt_maturity)

# Svensson
dt_curve = Date(2015, 08, 11)
curve_sven = InterestRates.IRCurve("dummy-continuous-svensson", InterestRates.Actual360(),
    InterestRates.ContinuousCompounding(), InterestRates.Svensson(), dt_curve,
    [0.1, 0.2, 0.3, 0.4, 0.5, 0.8])

mat_vec = [Date(2015,8,12), Date(2016,8,12)]
@test zero_rate(curve_sven, mat_vec) ≈ [0.300513102478340, 0.408050168725566]
@test discountfactor(curve_sven, mat_vec) ≈ [0.999165589696054, 0.659690510410030]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_NS, ERF(curve_NS, dt_maturity), InterestRates.yearfraction(curve_NS, dt_maturity)) ≈ zero_rate(curve_NS, dt_maturity)

# Splines

vert_x = [11, 15, 19, 23, 25]
vert_y = [0.10, 0.12, 0.20, 0.22, 0.2]

sp = InterestRates.splinefit([1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0])
InterestRates.splineint(sp, [5, 6])
sp = InterestRates.splinefit([1.0, 2.0, 3.0, 4.0], [1.0, 2.0, 3.0, 4.0])
InterestRates.splineint(sp, [1.0, 1.5])

sp = InterestRates.splinefit(vert_x, vert_y)
y = InterestRates.splineint(sp, convert(Vector{Int}, 1:30))
@test y[vert_x] ≈ vert_y

y_benchmark = [0.09756098, 0.09780488, 0.09804878, 0.09829268, 0.09853659, 0.09878049, 0.09902439, 0.09926829, 0.09951220, 0.09975610, 0.10000000, 0.10054116, 0.10286585,
0.10875762, 0.12000000, 0.13753049, 0.15890244, 0.18082317, 0.20000000, 0.21371189, 0.22152439, 0.22357470, 0.22000000, 0.21137195, 0.20000000, 0.18817073,
0.17634146, 0.16451220, 0.15268293, 0.14085366]

@test all(round.(y; digits=8) .== round.(y_benchmark; digits=8))

curve_spline_rates = InterestRates.IRCurve("dummy-SplineOnRates", InterestRates.Actual360(),
    InterestRates.ContinuousCompounding(), InterestRates.CubicSplineOnRates(), dt_curve,
    vert_x, vert_y)

@test zero_rate(curve_spline_rates, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(curve_spline_rates, [dt_curve+Dates.Day(11), dt_curve+Dates.Day(15)]) ≈ vert_y[1:2]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_spline_rates, ERF(curve_spline_rates, dt_maturity), InterestRates.yearfraction(curve_spline_rates, dt_maturity)) ≈ zero_rate(curve_spline_rates, dt_maturity)

mat_vec = [ Dates.Day(i) for i in 1:30 ] + dt_curve
@test zero_rate(curve_spline_rates, mat_vec) ≈ y

curve_spline_discount = InterestRates.IRCurve("dummy-SplineOnDiscountFactors", InterestRates.Actual360(),
    InterestRates.ContinuousCompounding(), InterestRates.CubicSplineOnDiscountFactors(), dt_curve,
    vert_x, vert_y)

@test zero_rate(curve_spline_discount, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(curve_spline_discount, [dt_curve+Dates.Day(11), dt_curve+Dates.Day(15)]) ≈ vert_y[1:2]

@test InterestRates.advancedays(InterestRates.BDays252(BusinessDays.Brazil()), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,8),Date(2015,9,9)]
@test InterestRates.advancedays(InterestRates.Actual360(), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,5),Date(2015,9,6)]
@test InterestRates.advancedays(InterestRates.Actual365(), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,5),Date(2015,9,6)]

param = 10
InterestRates.curve_set_dict_parameter!(curve_spline_discount, :custom_parameter, param)
@test InterestRates.curve_get_dict_parameter(curve_spline_discount, :custom_parameter) == param

# CompositeIRCurve
composite_curve = InterestRates.CompositeIRCurve(curve_spline_rates, curve_NS)
@test_throws AssertionError composite_curve_2 = InterestRates.CompositeIRCurve(curve_NS, curve_b252_ec_lin)
@test InterestRates.curve_get_date(composite_curve) == InterestRates.curve_get_date(curve_NS)
@test InterestRates.discountfactor(composite_curve, Date(2015,10,1)) ≈ InterestRates.discountfactor(curve_NS, Date(2015,10,1)) * InterestRates.discountfactor(curve_spline_rates, Date(2015,10,1))
@test InterestRates.ERF(composite_curve, Date(2015,10,1)) == InterestRates.ERF(curve_NS, Date(2015,10,1)) * InterestRates.ERF(curve_spline_rates, Date(2015,10,1))

# BufferedIRCurve
buffered_curve_ac360_cont_ff = InterestRates.BufferedIRCurve(curve_ac360_cont_ff)
dt_curve = InterestRates.curve_get_date(buffered_curve_ac360_cont_ff)

@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(15)) ≈ 0.15
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(15)) ≈ 0.15
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(19)) ≈ 0.20
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(19)) ≈ 0.20
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(23)) ≈ 0.19
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(23)) ≈ 0.19
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(16)) > 0.15
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(16)) > 0.15
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(17)) < 0.20
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(17)) < 0.20
@test forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) ≈ 0.2875 # forward_rate calculation on vertices
@test forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(13)) ≈ 0.2875 # forward_rate calculation on interpolated maturity
@test ERF(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(13)) ≈ 1.00466361875533 # ffwd interp on ERF
@test ERF(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(13)) ≈ 1.00466361875533

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(buffered_curve_ac360_cont_ff, ERF(buffered_curve_ac360_cont_ff, dt_maturity), InterestRates.yearfraction(buffered_curve_ac360_cont_ff, dt_maturity)) ≈ zero_rate(buffered_curve_ac360_cont_ff, dt_maturity)
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(13)) ≈ 0.128846153846152 # ffwd interp as zero_rate
@test ERF(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ 1.00158458746737
@test forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ 0.1425000000000040
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(30)) ≈ 0.1789166666666680 # ffwd extrap after last vertice
@test forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(50), dt_curve + Dates.Day(51))
@test forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(50), dt_curve + Dates.Day(100))

@test forward_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) ≈ 0.2875
@test zero_rate(buffered_curve_ac360_cont_ff, dt_curve + Dates.Day(9)) ≈ 0.05833333333333 # ffwd extrap before first vertice

@test discountfactor(buffered_curve_ac360_cont_ff, dt_curve) == 1
@test isnan(ERF_to_rate(buffered_curve_ac360_cont_ff, 1.0, 0.0))

include("usage.jl")
include("perftests.jl")
