
# Tests for module InterestRates

using Base.Test
using BusinessDays
using InterestRates

bd = BusinessDays
ir = InterestRates

vert_x = [11, 15, 19, 23]
vert_y = [0.10, 0.15, 0.20, 0.19]

dt_curve = Date(2015,08,03)

# Error testing
@test_throws ErrorException ir.IRCurve("", ir.Actual365(), ir.ExponentialCompounding(),
	ir.Linear(), dt_curve, [1, 2, 6, 5], [.1, .1, .1, .1])

@test_throws ErrorException ir.IRCurve("", ir.Actual365(), ir.ExponentialCompounding(),
	ir.Linear(), dt_curve, [1, 2, 3, 4], [.1, .1, .1])

@test_throws ErrorException ir.IRCurve("", ir.Actual365(), ir.ExponentialCompounding(),
	ir.Linear(), dt_curve, Array{Int}(0) , [.1, .1, .1])

@test_throws ErrorException ir.IRCurve("", ir.Actual365(), ir.ExponentialCompounding(),
	ir.Linear(), dt_curve, Array{Int}(1) , Array{Float64}(0))

@test_throws ErrorException ir.IRCurve("", ir.Actual365(), ir.ExponentialCompounding(),
	ir.Linear(), dt_curve, Array{Int}(0) , Array{Float64}(0))

bd.initcache(bd.Brazil())

curve_b252_ec_lin = ir.IRCurve("dummy-linear", ir.BDays252(bd.Brazil()),
	ir.ExponentialCompounding(), ir.Linear(), dt_curve,
	vert_x, vert_y)

@test_throws ErrorException zero_rate(curve_b252_ec_lin, dt_curve - Dates.Day(10))
 
@test ir.curve_get_name(curve_b252_ec_lin) == "dummy-linear"
@test ir.curve_get_date(curve_b252_ec_lin) == dt_curve

maturity_2_days = advancebdays(bd.Brazil(), dt_curve, vert_x[1] + 2)
yrs = (vert_x[1] + 2) / 252.0
zero_rate_2_days = 0.125
disc_2_days = 1.0 / ( (1.0 + zero_rate_2_days)^yrs)
@test zero_rate_2_days ≈ zero_rate(curve_b252_ec_lin, maturity_2_days) # Linear interpolation
@test disc_2_days ≈ discountfactor(curve_b252_ec_lin, maturity_2_days)
@test zero_rate(curve_b252_ec_lin, advancebdays(bd.Brazil(), dt_curve, 11)) ≈ 0.10
@test_throws ErrorException zero_rate(curve_b252_ec_lin, advancebdays(bd.Brazil(), dt_curve, -4)) # maturity before curve date
@test zero_rate(curve_b252_ec_lin, advancebdays(bd.Brazil(), dt_curve, 11-4)) ≈ 0.05 # extrapolate before first vertice
@test zero_rate(curve_b252_ec_lin, advancebdays(bd.Brazil(), dt_curve, 23+4)) ≈ 0.18 # extrapolate after last vertice

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_b252_ec_lin, ERF(curve_b252_ec_lin, dt_maturity), ir.yearfraction(curve_b252_ec_lin, dt_maturity)) ≈ zero_rate(curve_b252_ec_lin, dt_maturity)

curve_ac360_cont_ff = ir.IRCurve("dummy-cont-flatforward", ir.Actual360(),
	ir.ContinuousCompounding(), ir.FlatForward(), dt_curve,
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
@test ERF_to_rate(curve_ac360_cont_ff, ERF(curve_ac360_cont_ff, dt_maturity), ir.yearfraction(curve_ac360_cont_ff, dt_maturity)) ≈ zero_rate(curve_ac360_cont_ff, dt_maturity)
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
n_curve = ir.NullIRCurve()
@test n_curve == ir.NullIRCurve() # Should be singleton
@test ERF(n_curve, Date(2000,1,1)) == 1.0
@test ER(n_curve, Date(2000,1,1)) == 0.0
@test discountfactor(n_curve, Date(2000,1,1)) == 1.0
@test ir.curve_get_name(n_curve) == "NullCurve"
@test isnullcurve(n_curve) == true
@test isnullcurve(curve_ac360_cont_ff) == false
@test forward_rate(n_curve, Date(2000,1,1), Date(2000,1,2)) == 0.0
@test zero_rate(n_curve, Date(2000,1,1)) == 0.0
@test zero_rate(n_curve, [Date(2000,1,1), Date(2000,1,2)]) == [ 0.0, 0.0 ]

# Tests for vector functions
dt_curve = Date(2015, 08, 07)
curve_ac365_simple_linear = ir.IRCurve("dummy-simple-linear", ir.Actual365(),
	ir.SimpleCompounding(), ir.Linear(), dt_curve,
	vert_x, vert_y)
mat_vec = [ Date(2015,08,17), Date(2015,08,18), Date(2015,08,19), Date(2015,08,20), Date(2015,08,21), Date(2015,08,22)]
@test zero_rate(curve_ac365_simple_linear, mat_vec) ≈ [0.0875,0.1,0.1125,0.1250,0.1375,0.15]
@test ERF(curve_ac365_simple_linear, mat_vec) ≈ [1.00239726027397, 1.00301369863014, 1.00369863013699, 1.00445205479452, 1.00527397260274, 1.00616438356164]
@test discountfactor(curve_ac365_simple_linear, mat_vec) ≈ [0.997608472839084, 0.996995356459984, 0.996314999317592, 0.995567678145244, 0.994753696259454, 0.993873383253914]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_ac365_simple_linear, ERF(curve_ac365_simple_linear, dt_maturity), ir.yearfraction(curve_ac365_simple_linear, dt_maturity)) ≈ zero_rate(curve_ac365_simple_linear, dt_maturity)

comp = ir.CompositeInterpolation(ir.StepFunction(), ir.Linear(), ir.StepFunction())
curve_ac365_simple_comp = ir.IRCurve("dummy-simple-linear", ir.Actual365(),
	ir.SimpleCompounding(), comp, dt_curve,
	vert_x, vert_y)
@test zero_rate(curve_ac365_simple_comp, mat_vec) ≈ [0.1,0.1,0.1125,0.1250,0.1375,0.15]
@test zero_rate(curve_ac365_simple_comp, Date(2100,2,2)) ≈ 0.19

curve_step = ir.IRCurve("step-curve", ir.Actual365(), 
	ir.SimpleCompounding(), ir.StepFunction(), dt_curve,
	vert_x, vert_y)
mat_vec = [ Date(2015,08,08), Date(2015,08,12), Date(2015,08,17), Date(2015,08,18), Date(2015,08,19), 
	Date(2015,08,21), Date(2015,08,22), Date(2015,08,23), Date(2015,08,25), Date(2015,08,26),
	Date(2015,08,27), Date(2015,08,29), Date(2015,08,30), Date(2015,08,31), Date(2015,09,26)]

@test zero_rate(curve_step, mat_vec) ≈ [0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.15, 0.15, 0.15, 0.20, 0.20, 0.20, 0.19, 0.19, 0.19]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_step, ERF(curve_step, dt_maturity), ir.yearfraction(curve_step, dt_maturity)) ≈ zero_rate(curve_step, dt_maturity)

# Nelson Siegel
dt_curve = Date(2015, 08, 11)
curve_NS = ir.IRCurve("dummy-continuous-nelsonsiegel", ir.Actual360(),
	ir.ContinuousCompounding(), ir.NelsonSiegel(), dt_curve,
	[0.1, 0.2, 0.3, 0.5])

mat_vec = [Date(2015,8,12), Date(2016,8,12)]
@test zero_rate(curve_NS, mat_vec) ≈ [0.300069315921728, 0.311522078457982]
@test discountfactor(curve_NS, mat_vec) ≈ [0.999166821408637, 0.727908844513432]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_NS, ERF(curve_NS, dt_maturity), ir.yearfraction(curve_NS, dt_maturity)) ≈ zero_rate(curve_NS, dt_maturity)

# Svensson
dt_curve = Date(2015, 08, 11)
curve_sven = ir.IRCurve("dummy-continuous-svensson", ir.Actual360(),
	ir.ContinuousCompounding(), ir.Svensson(), dt_curve,
	[0.1, 0.2, 0.3, 0.4, 0.5, 0.8])

mat_vec = [Date(2015,8,12), Date(2016,8,12)]
@test zero_rate(curve_sven, mat_vec) ≈ [0.300513102478340, 0.408050168725566]
@test discountfactor(curve_sven, mat_vec) ≈ [0.999165589696054, 0.659690510410030]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_NS, ERF(curve_NS, dt_maturity), ir.yearfraction(curve_NS, dt_maturity)) ≈ zero_rate(curve_NS, dt_maturity)

# Splines

vert_x = [11, 15, 19, 23, 25]
vert_y = [0.10, 0.12, 0.20, 0.22, 0.2]

sp = ir.splinefit([1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0])
ir.splineint(sp, [5, 6])
sp = ir.splinefit([1.0, 2.0, 3.0, 4.0], [1.0, 2.0, 3.0, 4.0])
ir.splineint(sp, [1.0, 1.5])

sp = ir.splinefit(vert_x, vert_y)
y = ir.splineint(sp, convert(Vector{Int}, 1:30))
@test y[vert_x] ≈ vert_y

y_benchmark = [0.09756098, 0.09780488, 0.09804878, 0.09829268, 0.09853659, 0.09878049, 0.09902439, 0.09926829, 0.09951220, 0.09975610, 0.10000000, 0.10054116, 0.10286585,
0.10875762, 0.12000000, 0.13753049, 0.15890244, 0.18082317, 0.20000000, 0.21371189, 0.22152439, 0.22357470, 0.22000000, 0.21137195, 0.20000000, 0.18817073,
0.17634146, 0.16451220, 0.15268293, 0.14085366]

@test isapprox(y, y_benchmark; atol=5e-9)

curve_spline_rates = ir.IRCurve("dummy-SplineOnRates", ir.Actual360(),
	ir.ContinuousCompounding(), ir.CubicSplineOnRates(), dt_curve,
	vert_x, vert_y)

@test zero_rate(curve_spline_rates, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(curve_spline_rates, [dt_curve+Dates.Day(11), dt_curve+Dates.Day(15)]) ≈ vert_y[1:2]

dt_maturity = dt_curve+Dates.Day(30)
@test ERF_to_rate(curve_spline_rates, ERF(curve_spline_rates, dt_maturity), ir.yearfraction(curve_spline_rates, dt_maturity)) ≈ zero_rate(curve_spline_rates, dt_maturity)

mat_vec = [ Dates.Day(i) for i in 1:30 ] + dt_curve
@test zero_rate(curve_spline_rates, mat_vec) ≈ y

curve_spline_discount = ir.IRCurve("dummy-SplineOnDiscountFactors", ir.Actual360(),
	ir.ContinuousCompounding(), ir.CubicSplineOnDiscountFactors(), dt_curve,
	vert_x, vert_y)

@test zero_rate(curve_spline_discount, dt_curve + Dates.Day(11)) ≈ 0.1
@test zero_rate(curve_spline_discount, [dt_curve+Dates.Day(11), dt_curve+Dates.Day(15)]) ≈ vert_y[1:2]

@test ir.advancedays(ir.BDays252(bd.Brazil()), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,8),Date(2015,9,9)]
@test ir.advancedays(ir.Actual360(), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,5),Date(2015,9,6)]
@test ir.advancedays(ir.Actual365(), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,5),Date(2015,9,6)]

param = 10
ir.curve_set_dict_parameter!(curve_spline_discount, :custom_parameter, param)
@test ir.curve_get_dict_parameter(curve_spline_discount, :custom_parameter) == param

# CompositeIRCurve
composite_curve = ir.CompositeIRCurve(curve_spline_rates, curve_NS)
@test_throws AssertionError composite_curve_2 = ir.CompositeIRCurve(curve_NS, curve_b252_ec_lin)
@test ir.curve_get_date(composite_curve) == ir.curve_get_date(curve_NS)
@test ir.discountfactor(composite_curve, Date(2015,10,1)) ≈ ir.discountfactor(curve_NS, Date(2015,10,1)) * ir.discountfactor(curve_spline_rates, Date(2015,10,1))
@test ir.ERF(composite_curve, Date(2015,10,1)) == ir.ERF(curve_NS, Date(2015,10,1)) * ir.ERF(curve_spline_rates, Date(2015,10,1))

include("usage.jl")
include("perftests.jl")
