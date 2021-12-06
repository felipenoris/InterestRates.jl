
# Tests for module InterestRates

using Test
using BusinessDays
using InterestRates
using Dates

BusinessDays.initcache(BusinessDays.Brazil())

@testset "errors" begin
    dt_curve = Date(2015,08,03)

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
end

@testset "daycount equality" begin
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

@testset "hash and equals" begin
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

@testset "Linear Interp" begin

    vert_x = [11, 15, 19, 23]
    vert_y = [0.10, 0.15, 0.20, 0.19]

    dt_curve = Date(2015,08,03)

    curve_b252_ec_lin = InterestRates.IRCurve("dummy-linear", InterestRates.BDays252(BusinessDays.Brazil()),
        InterestRates.ExponentialCompounding(), InterestRates.Linear(), dt_curve,
        vert_x, vert_y)

    @test InterestRates.curve_get_name(curve_b252_ec_lin) == "dummy-linear"
    @test InterestRates.curve_get_date(curve_b252_ec_lin) == dt_curve
    @test InterestRates.curve_get_method(curve_b252_ec_lin) == InterestRates.Linear()

    maturity_2_days = advancebdays(BusinessDays.Brazil(), dt_curve, vert_x[1] + 2)
    maturity_3_days = advancebdays(BusinessDays.Brazil(), dt_curve, vert_x[1] + 3)
    yrs = (vert_x[1] + 2) / 252.0
    zero_rate_2_days = 0.125
    disc_2_days = 1.0 / ( (1.0 + zero_rate_2_days)^yrs)
    @test zero_rate_2_days ≈ zero_rate(curve_b252_ec_lin, maturity_2_days) # Linear interpolation
    @test disc_2_days ≈ discountfactor(curve_b252_ec_lin, maturity_2_days)
    @test discountfactor(curve_b252_ec_lin, maturity_2_days, maturity_3_days) ≈ discountfactor(curve_b252_ec_lin, maturity_3_days) / discountfactor(curve_b252_ec_lin, maturity_2_days)
    @test zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, 11)) ≈ 0.10
    @test_throws AssertionError zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, -4)) # maturity before curve date
    @test zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, 11-4)) ≈ 0.05 # extrapolate before first vertice
    @test zero_rate(curve_b252_ec_lin, advancebdays(BusinessDays.Brazil(), dt_curve, 23+4)) ≈ 0.18 # extrapolate after last vertice

    dt_maturity = dt_curve+Dates.Day(30)
    @test ERF_to_rate(curve_b252_ec_lin, ERF(curve_b252_ec_lin, dt_maturity), InterestRates.yearfraction(curve_b252_ec_lin, dt_maturity)) ≈ zero_rate(curve_b252_ec_lin, dt_maturity)
    @test_throws AssertionError zero_rate(curve_b252_ec_lin, dt_curve - Dates.Day(10))
end

@testset "Flat Forward Interp" begin

    vert_x = [11, 15, 19, 23]
    vert_y = [0.10, 0.15, 0.20, 0.19]

    dt_curve = Date(2015,08,03)

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
    @test discountfactor(curve_ac360_cont_ff, dt_curve + Dates.Day(20)) ≈ 0.9891083592630893

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
    @test isnan(ERF_to_rate(curve_ac360_cont_ff, 1.0, InterestRates.YearFraction(0.0)))
    @test isnullcurve(curve_ac360_cont_ff) == false
end

@testset "Null Curve" begin
    n_curve = InterestRates.NullIRCurve()
    @test n_curve == InterestRates.NullIRCurve() # Should be singleton
    @test ERF(n_curve, Date(2000,1,1)) == 1.0
    @test ER(n_curve, Date(2000,1,1)) == 0.0
    @test discountfactor(n_curve, Date(2000,1,1)) == 1.0
    @test InterestRates.curve_get_name(n_curve) == "NullCurve"
    @test isnullcurve(n_curve) == true
    @test forward_rate(n_curve, Date(2000,1,1), Date(2000,1,2)) == 0.0
    @test zero_rate(n_curve, Date(2000,1,1)) == 0.0
    @test zero_rate(n_curve, [Date(2000,1,1), Date(2000,1,2)]) == [ 0.0, 0.0 ]
end

@testset "Vector functions" begin
    dt_curve = Date(2015, 08, 07)

    vert_x = [11, 15, 19, 23]
    vert_y = [0.10, 0.15, 0.20, 0.19]

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
end

@testset "Nelson Siegel" begin
    dt_curve = Date(2015, 08, 11)
    curve_NS = InterestRates.IRCurve("dummy-continuous-nelsonsiegel", InterestRates.Actual360(),
        InterestRates.ContinuousCompounding(), InterestRates.NelsonSiegel(), dt_curve,
        [0.1, 0.2, 0.3, 0.5])

    mat_vec = [Date(2015,8,12), Date(2016,8,12)]
    @test zero_rate(curve_NS, mat_vec) ≈ [0.300069315921728, 0.311522078457982]
    @test discountfactor(curve_NS, mat_vec) ≈ [0.999166821408637, 0.727908844513432]

    dt_maturity = dt_curve+Dates.Day(30)
    @test ERF_to_rate(curve_NS, ERF(curve_NS, dt_maturity), InterestRates.yearfraction(curve_NS, dt_maturity)) ≈ zero_rate(curve_NS, dt_maturity)
end

@testset "Svensson" begin
    dt_curve = Date(2015, 08, 11)
    curve_sven = InterestRates.IRCurve("dummy-continuous-svensson", InterestRates.Actual360(),
        InterestRates.ContinuousCompounding(), InterestRates.Svensson(), dt_curve,
        [0.1, 0.2, 0.3, 0.4, 0.5, 0.8])

    mat_vec = [Date(2015,8,12), Date(2016,8,12)]
    @test zero_rate(curve_sven, mat_vec) ≈ [0.300513102478340, 0.408050168725566]
    @test discountfactor(curve_sven, mat_vec) ≈ [0.999165589696054, 0.659690510410030]

    dt_maturity = dt_curve+Dates.Day(30)
    @test ERF_to_rate(curve_sven, ERF(curve_sven, dt_maturity), InterestRates.yearfraction(curve_sven, dt_maturity)) ≈ zero_rate(curve_sven, dt_maturity)
end

@testset "Splines" begin

    dt_curve = Date(2015, 08, 11)

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
    @test InterestRates.advancedays(InterestRates.Thirty360(), Date(2015,9,1), [0, 1, 3, 4, 5]) == [Date(2015,9,1),Date(2015,9,2),Date(2015,9,4),Date(2015,9,5),Date(2015,9,6)]

    param = 10
    InterestRates.curve_set_dict_parameter!(curve_spline_discount, :custom_parameter, param)
    @test InterestRates.curve_get_dict_parameter(curve_spline_discount, :custom_parameter) == param
end

@testset "ComposeFactorCurve" begin
    dt_curve = Date(2015, 08, 11)

    vert_x = [11, 15, 19, 23, 25]
    vert_y = [0.10, 0.12, 0.20, 0.22, 0.2]

    curve_spline_rates = InterestRates.IRCurve("dummy-SplineOnRates", InterestRates.Actual360(),
        InterestRates.ContinuousCompounding(), InterestRates.CubicSplineOnRates(), dt_curve,
        vert_x, vert_y)

    curve_NS = InterestRates.IRCurve("dummy-continuous-nelsonsiegel", InterestRates.Actual360(),
        InterestRates.ContinuousCompounding(), InterestRates.NelsonSiegel(), dt_curve,
        [0.1, 0.2, 0.3, 0.5])

    @testset "ComposeMult" begin
        compose_mult_curve = InterestRates.ComposeProdFactorCurve(curve_spline_rates, curve_NS, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())

        curve_b252_ec_lin = InterestRates.IRCurve("dummy-linear", InterestRates.BDays252(BusinessDays.BRSettlement()),
            InterestRates.ExponentialCompounding(), InterestRates.Linear(), Date(2015, 8, 10),
            vert_x, vert_y)

        @test_throws AssertionError InterestRates.ComposeProdFactorCurve(curve_NS, curve_b252_ec_lin, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())
        @test InterestRates.curve_get_name(compose_mult_curve) == ""
        @test InterestRates.curve_get_date(compose_mult_curve) == InterestRates.curve_get_date(curve_NS)
        @test InterestRates.discountfactor(compose_mult_curve, Date(2015,10,1)) ≈ InterestRates.discountfactor(curve_NS, Date(2015,10,1)) * InterestRates.discountfactor(curve_spline_rates, Date(2015,10,1))
        @test InterestRates.ERF(compose_mult_curve, Date(2015,10,1)) == InterestRates.ERF(curve_NS, Date(2015,10,1)) * InterestRates.ERF(curve_spline_rates, Date(2015,10,1))

        let
            maturity = Date(2015,10,1)
            erf = InterestRates.ERF(compose_mult_curve, maturity)
            yf = BusinessDays.bdayscount(BusinessDays.BRSettlement(), dt_curve, maturity) / 252
            @test  InterestRates.zero_rate(compose_mult_curve, maturity) ≈ erf^(1/yf) - 1
        end

        compose_mult_named_curve = InterestRates.ComposeProdFactorCurve("curve-name", curve_spline_rates, curve_NS, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())
        @test InterestRates.curve_get_name(compose_mult_named_curve) == "curve-name"
    end

    @testset "ComposeDiv" begin
        compose_div_curve = InterestRates.ComposeDivFactorCurve(curve_spline_rates, curve_NS, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())
        @test InterestRates.discountfactor(compose_div_curve, Date(2015,10,1)) ≈ InterestRates.discountfactor(curve_spline_rates, Date(2015,10,1)) / InterestRates.discountfactor(curve_NS, Date(2015,10,1))
        @test InterestRates.ERF(compose_div_curve, Date(2015,10,1)) == InterestRates.ERF(curve_spline_rates, Date(2015,10,1)) / InterestRates.ERF(curve_NS, Date(2015,10,1))
        @test InterestRates.curve_get_name(compose_div_curve) == ""

        compose_div_named_curve = InterestRates.ComposeDivFactorCurve("curve-name", curve_spline_rates, curve_NS, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())
        @test InterestRates.curve_get_name(compose_div_named_curve) == "curve-name"
    end

    @testset "ComposeMult -> ComposeDiv" begin

        vert_x = [11, 15, 19, 23]
        vert_y = [0.10, 0.15, 0.20, 0.19]

        curve_ac360_cont_ff = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.Actual360(),
            InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
            vert_x, vert_y)

        compose_mult_curve = InterestRates.ComposeProdFactorCurve(curve_spline_rates, curve_NS, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())
        compose_div_mult_curve = InterestRates.ComposeDivFactorCurve(compose_mult_curve, curve_ac360_cont_ff, InterestRates.BDays252(BusinessDays.BRSettlement()), InterestRates.ExponentialCompounding())
        @test InterestRates.discountfactor(compose_div_mult_curve, Date(2015,10,1)) ≈ InterestRates.discountfactor(curve_NS, Date(2015,10,1)) * InterestRates.discountfactor(curve_spline_rates, Date(2015,10,1)) / InterestRates.discountfactor(curve_ac360_cont_ff, Date(2015,10,1))

        let
            maturity = Date(2015,10,1)
            erf = InterestRates.ERF(curve_NS, Date(2015,10,1)) * InterestRates.ERF(curve_spline_rates, Date(2015,10,1)) / InterestRates.ERF(curve_ac360_cont_ff, Date(2015,10,1))
            yf = BusinessDays.bdayscount(BusinessDays.BRSettlement(), dt_curve, maturity) / 252
            @test  InterestRates.zero_rate(compose_div_mult_curve, maturity) ≈ erf^(1/yf) - 1
        end
    end
end

@testset "BufferedIRCurve" begin

    vert_x = [11, 15, 19, 23]
    vert_y = [0.10, 0.15, 0.20, 0.19]

    dt_curve = Date(2015,08,03)

    curve_ac360_cont_ff = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.Actual360(),
        InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
        vert_x, vert_y)

    buffered_curve_ac360_cont_ff = InterestRates.BufferedIRCurve(curve_ac360_cont_ff)
    dt_curve = InterestRates.curve_get_date(buffered_curve_ac360_cont_ff)

    Threads.@threads for i in 1:10
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
        @test isnan(ERF_to_rate(buffered_curve_ac360_cont_ff, 1.0, InterestRates.YearFraction(0.0)))
    end
end

@testset "YearFraction" begin

    @testset "YearFraction API" begin
        yf = InterestRates.YearFraction(1)
        @test iszero(InterestRates.YearFraction(0))
        @test iszero(InterestRates.YearFraction(0.0))
        @test zero(yf) == InterestRates.YearFraction(0)
        @test zero(yf) == InterestRates.YearFraction(0.0)
        @test iszero(zero(yf))

        InterestRates.yearfractionvalue(InterestRates.Actual360(), 10) == 10 / 360
        InterestRates.yearfractionvalue(InterestRates.Actual360(), Date(2020, 2, 1), Date(2020, 2, 11)) == 10 / 360
    end
    vert_x = [1, 11, 15, 19, 23, 2520]
    vert_y = [0.13, 0.14, 0.15, 0.20, 0.19, 0.25 ]

    dt_curve = Date(2015,08,03)

    curve_b252_ec_lin = InterestRates.IRCurve("dummy-linear", InterestRates.BDays252(BusinessDays.Brazil()),
        InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,
        vert_x, vert_y)

    half_a_day = InterestRates.YearFraction(1 // 504)
    one_day_and_a_half = InterestRates.YearFraction(3 // 504)
    a_float = InterestRates.YearFraction(1.75 / 252)
    an_int = InterestRates.YearFraction(1)
    yf_1_day = InterestRates.YearFraction(1/252)
    yf_2_days = InterestRates.YearFraction(2/252)

    @test InterestRates.days_to_maturity(curve_b252_ec_lin, an_int) == InterestRates.value(an_int) * 252
    @test InterestRates.days_to_maturity(curve_b252_ec_lin, a_float) == InterestRates.value(a_float) * 252
    @test InterestRates.days_to_maturity(curve_b252_ec_lin, half_a_day) == InterestRates.value(half_a_day) * 252
    @test InterestRates.days_to_maturity(curve_b252_ec_lin, one_day_and_a_half) == InterestRates.value(one_day_and_a_half) * 252

    dt_maturity_1_day = BusinessDays.advancebdays(BusinessDays.Brazil(), dt_curve, 1)
    dt_maturity_2_days = BusinessDays.advancebdays(BusinessDays.Brazil(), dt_curve, 2)
    dt_maturity_1_year = BusinessDays.advancebdays(BusinessDays.Brazil(), dt_curve, 252)

    @test InterestRates.yearfractionvalue(curve_b252_ec_lin, dt_maturity_2_days) == 2 / 252

    @testset "Linear" begin
        curve = curve_b252_ec_lin
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)

        let
            yf_diff = InterestRates.value(one_day_and_a_half) - InterestRates.value(half_a_day)
            df = discountfactor(curve, half_a_day, one_day_and_a_half)
            fwd_rate = ((1/df) - 1)/yf_diff
            @test forward_rate(curve, half_a_day, one_day_and_a_half) ≈ fwd_rate
        end
    end

    @testset "FlatForward" begin
        curve = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
            vert_x, vert_y)

        @test discountfactor(curve, one_day_and_a_half) ≈ exp(-InterestRates.zero_rate(curve, one_day_and_a_half) * 3 / 504)
        @test discountfactor(curve, InterestRates.YearFraction(2 / 252)) ≈ exp(-InterestRates.zero_rate(curve, dt_maturity_2_days) * 2 / 252)
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)

        let
            yf_diff = InterestRates.value(one_day_and_a_half) - InterestRates.value(half_a_day)
            df = discountfactor(curve, half_a_day, one_day_and_a_half)
            fwd_rate = -log(df)/yf_diff
            @test forward_rate(curve, half_a_day, one_day_and_a_half) ≈ fwd_rate
        end
    end

    @testset "CubicSplineOnRates" begin
        curve = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ExponentialCompounding(), InterestRates.CubicSplineOnRates(), dt_curve,
            vert_x, vert_y)

        @test discountfactor(curve, one_day_and_a_half) ≈ 1.0 / (( 1 + InterestRates.zero_rate(curve, one_day_and_a_half))^( 3 / 504))
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end

    @testset "CubicSplineOnDiscountFactors" begin
        curve = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ExponentialCompounding(), InterestRates.CubicSplineOnDiscountFactors(), dt_curve,
            vert_x, vert_y)

        @test discountfactor(curve, one_day_and_a_half) ≈ 1.0 / (( 1 + InterestRates.zero_rate(curve, one_day_and_a_half))^( 3 / 504))
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end

    @testset "Svensson" begin
        curve = InterestRates.IRCurve("dummy-continuous-svensson", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ExponentialCompounding(), InterestRates.Svensson(), dt_curve,
            [0.1, 0.2, 0.3, 0.4, 0.5, 0.8])

        @test discountfactor(curve, one_day_and_a_half) ≈ 1.0 / (( 1 + InterestRates.zero_rate(curve, one_day_and_a_half))^( 3 / 504))
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end

    @testset "NelsonSiegel" begin
        curve = InterestRates.IRCurve("dummy-continuous-nelsonsiegel", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ExponentialCompounding(), InterestRates.NelsonSiegel(), dt_curve,
            [0.1, 0.2, 0.3, 0.5])

        @test discountfactor(curve, one_day_and_a_half) ≈ 1.0 / (( 1 + InterestRates.zero_rate(curve, one_day_and_a_half))^( 3 / 504))
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end

    @testset "StepFunction" begin
        curve = InterestRates.IRCurve("step-curve", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ExponentialCompounding(), InterestRates.StepFunction(), dt_curve,
            vert_x, vert_y)

        @test discountfactor(curve, one_day_and_a_half) ≈ 1.0 / (( 1 + InterestRates.zero_rate(curve, one_day_and_a_half))^( 3 / 504))
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end

    @testset "CompositeInterpolation" begin
        comp = InterestRates.CompositeInterpolation(InterestRates.StepFunction(), InterestRates.Linear(), InterestRates.StepFunction())

        curve = InterestRates.IRCurve("dummy-simple-linear", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ExponentialCompounding(), comp, dt_curve,
            vert_x, vert_y)

        @test discountfactor(curve, one_day_and_a_half) ≈ 1.0 / (( 1 + InterestRates.zero_rate(curve, one_day_and_a_half))^( 3 / 504))
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end

    @testset "BufferedIRCurve" begin
        curve = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.BDays252(BusinessDays.Brazil()),
            InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
            vert_x, vert_y)

        curve = InterestRates.BufferedIRCurve(curve)

        @test discountfactor(curve, one_day_and_a_half) ≈ exp(-InterestRates.zero_rate(curve, one_day_and_a_half) * 3 / 504)
        @test discountfactor(curve, InterestRates.YearFraction(2 / 252)) ≈ exp(-InterestRates.zero_rate(curve, dt_maturity_2_days) * 2 / 252)
        @test discountfactor(curve, half_a_day) > discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, dt_maturity_1_day) > discountfactor(curve, one_day_and_a_half)
        @test discountfactor(curve, one_day_and_a_half) > discountfactor(curve, a_float)
        @test discountfactor(curve, a_float) > discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, an_int) ≈ discountfactor(curve, dt_maturity_1_year)
        @test discountfactor(curve, yf_1_day) ≈ discountfactor(curve, dt_maturity_1_day)
        @test discountfactor(curve, yf_2_days) ≈ discountfactor(curve, dt_maturity_2_days)
        @test discountfactor(curve, yf_1_day, yf_2_days) ≈ discountfactor(curve, dt_maturity_1_day, dt_maturity_2_days)
        @test discountfactor(curve, half_a_day, one_day_and_a_half) ≈ discountfactor(curve, one_day_and_a_half) / discountfactor(curve, half_a_day)
    end
end

@testset "CurveMap" begin
    vert_x = [11, 15, 19, 23]
    vert_y = [0.09, 0.14, 0.19, 0.18]

    # parallel shock of 1%
    function map_parallel_1pct(rate, maturity)
        return rate + 0.01
    end

    dt_curve = Date(2015,08,03)

    curve_map = InterestRates.CurveMap("parallel-1pct", map_parallel_1pct, InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.Actual360(),
        InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
        vert_x, vert_y))

    @test InterestRates.curve_get_name(curve_map) == "parallel-1pct"
    @test zero_rate(curve_map, dt_curve + Dates.Day(11)) ≈ 0.1
    @test zero_rate(curve_map, dt_curve + Dates.Day(15)) ≈ 0.15
    @test zero_rate(curve_map, dt_curve + Dates.Day(19)) ≈ 0.20
    @test zero_rate(curve_map, dt_curve + Dates.Day(23)) ≈ 0.19
    @test zero_rate(curve_map, dt_curve + Dates.Day(16)) > 0.15
    @test zero_rate(curve_map, dt_curve + Dates.Day(17)) < 0.20
    @test forward_rate(curve_map, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) ≈ 0.2875 # forward_rate calculation on vertices
    @test forward_rate(curve_map, dt_curve + Dates.Day(11), dt_curve + Dates.Day(13)) ≈ 0.2875 # forward_rate calculation on interpolated maturity
    @test ERF(curve_map, dt_curve + Dates.Day(13)) ≈ 1.00466361875533 # ffwd interp on ERF
    @test discountfactor(curve_map, dt_curve + Dates.Day(20)) ≈ 0.9891083592630893

    dt_maturity = dt_curve+Dates.Day(30)
    @test ERF_to_rate(curve_map, ERF(curve_map, dt_maturity), InterestRates.yearfraction(curve_map, dt_maturity)) ≈ zero_rate(curve_map, dt_maturity)
    @test zero_rate(curve_map, dt_curve + Dates.Day(13)) ≈ 0.128846153846152 # ffwd interp as zero_rate
    @test ERF(curve_map, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ 1.00158458746737
    @test forward_rate(curve_map, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ 0.1425000000000040
    @test zero_rate(curve_map, dt_curve + Dates.Day(30)) ≈ 0.1789166666666680 # ffwd extrap after last vertice
    @test forward_rate(curve_map, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ forward_rate(curve_map, dt_curve + Dates.Day(50), dt_curve + Dates.Day(51))
    @test forward_rate(curve_map, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) ≈ forward_rate(curve_map, dt_curve + Dates.Day(50), dt_curve + Dates.Day(100))

    @test forward_rate(curve_map, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) ≈ 0.2875
    @test zero_rate(curve_map, dt_curve + Dates.Day(9)) ≈ 0.05833333333333 # ffwd extrap before first vertice

    @test discountfactor(curve_map, dt_curve) == 1
    @test isnan(ERF_to_rate(curve_map, 1.0, InterestRates.YearFraction(0.0)))
    @test isnullcurve(curve_map) == false

end

@testset "Buffered CurveMap" begin
    
    flat_curve = InterestRates.IRCurve(
        "flat", InterestRates.Actual360(), InterestRates.SimpleCompounding(), InterestRates.StepFunction(),
        Date(2021,1,1), [1], [0.1]
    )
    @test InterestRates.zero_rate(flat_curve, Date(2022,1,1)) ≈ 0.1

    map_curve = InterestRates.CurveMap("mapped", (r,m) -> r+0.05, flat_curve)
    @test InterestRates.zero_rate(map_curve, Date(2022,1,1)) ≈ 0.15

    buffered_curve = InterestRates.BufferedIRCurve(map_curve)
    @test InterestRates.zero_rate(buffered_curve, Date(2022,1,1)) ≈ 0.15

end

@testset "DailyDatesRange" begin
    @testset "bdays252" begin
        dd = InterestRates.DailyDatesRange(Date(2020, 4, 29), Date(2020, 5, 6), InterestRates.BDays252(BusinessDays.BRSettlement()))
        result_dates = [ Date(2020, 4, 29), Date(2020, 4, 30), Date(2020, 5, 4), Date(2020, 5, 5), Date(2020, 5, 6) ]
        @test firstindex(dd) == 1
        @test !isempty(dd)
        @test eltype(dd) == Date
        @test length(dd) == length(result_dates)
        @test lastindex(dd) == lastindex(result_dates)
        @test issorted(dd)
        @test InterestRates.yearfractionvalue(dd) == 1 / 252
        @test minimum(dd) == Date(2020, 4, 29)
        @test maximum(dd) == Date(2020, 5, 6)

        for dt in result_dates
            @test dt ∈ dd
        end

        @test !in(Date(2020, 4, 28), dd)
        @test !in(Date(2020, 5, 1), dd)
        @test !in(Date(2020, 5, 2), dd)
        @test !in(Date(2020, 5, 7), dd)

        let
            i = 1

            for dt in dd
                @test dt == result_dates[i]
                i += 1
            end

            @test i == length(result_dates) + 1
        end

        for i in eachindex(dd)
            @test dd[i] == result_dates[i]
        end

        for (i, dt) in enumerate(dd)
            @test dt == result_dates[i]
        end

        @test collect(dd) == result_dates

        reversed_dd = reverse(dd)
        @test isa(reversed_dd, InterestRates.DailyDatesRange)
        @test !issorted(reversed_dd)
        @test collect(reversed_dd) == reverse(result_dates)
        @test minimum(reversed_dd) == Date(2020, 4, 29)
        @test maximum(reversed_dd) == Date(2020, 5, 6)

        let
            i = length(result_dates)

            for dt in reversed_dd
                @test dt == result_dates[i]
                i -= 1
            end

            @test i == 0
        end
    end

    @testset "Actual360" begin
        dd = InterestRates.DailyDatesRange(Date(2020, 4, 29), Date(2020, 5, 6), InterestRates.Actual360())
        @test !isempty(dd)
        result_dates = collect(Date(2020, 4, 29):Dates.Day(1):Date(2020, 5, 6))
        @test collect(dd) == result_dates

        for dt in result_dates
            @test dt ∈ dd
        end

        @test !in(Date(2020, 4, 28), dd)
        @test !in(Date(2020, 5, 7), dd)
    end
end

@testset "Thirty360" begin

    dc = InterestRates.Thirty360()
    # usual rule: ((d2-d1) + (m2-m1)*30 + (y2-y1)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2012, 2,28)) == ((28-28) + (2-12)*30 + (2012-2011)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2012, 2,29)) == ((29-28) + (2-12)*30 + (2012-2011)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2012, 3, 1)) == ((1-28) + (3-12)*30 + (2012-2011)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2016, 2,28)) == ((28-28) + (2-12)*30 + (2016-2011)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2016, 2,29)) == ((29-28) + (2-12)*30 + (2016-2011)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2016, 3, 1)) == ((1-28) + (3-12)*30 + (2016-2011)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 2,28), Date(2012, 3,28)) == ((28-28) + (3-2)*30 + (2012-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 2,29), Date(2012, 3,28)) == ((28-29) + (3-2)*30 + (2012-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 3, 1), Date(2012, 3,28)) == ((28-1) + (3-3)*30 + (2012-2012)*360)/360

    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,29), Date(2013, 8,29)) == ((29-29) + (8-5)*30 + (2013-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,29), Date(2013, 8,30)) == ((30-29) + (8-5)*30 + (2013-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,29), Date(2013, 8,31)) == ((31-29) + (8-5)*30 + (2013-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,30), Date(2013, 8,29)) == ((29-30) + (8-5)*30 + (2013-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,30), Date(2013, 8,30)) == ((30-30) + (8-5)*30 + (2013-2012)*360)/360
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,30), Date(2013, 8,31)) == ((30-30) + (8-5)*30 + (2013-2012)*360)/360 # exception
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,31), Date(2013, 8,29)) == ((29-30) + (8-5)*30 + (2013-2012)*360)/360 # exception
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,31), Date(2013, 8,30)) == ((30-30) + (8-5)*30 + (2013-2012)*360)/360 # exception
    @test InterestRates.yearfractionvalue(dc, Date(2012, 5,31), Date(2013, 8,31)) == ((30-30) + (8-5)*30 + (2013-2012)*360)/360 # exception

    # zeros
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2011,12,28)) == 0
    @test InterestRates.yearfractionvalue(dc, Date(2011,12,31), Date(2011,12,31)) == 0
    @test InterestRates.yearfractionvalue(dc, Date(2012, 2,28), Date(2012, 2,28)) == 0
    @test InterestRates.yearfractionvalue(dc, Date(2012, 2,29), Date(2012, 2,29)) == 0

    # reflection
    @test InterestRates.yearfractionvalue(dc, Date(2012, 2,28), Date(2011,12,28)) == -InterestRates.yearfractionvalue(dc, Date(2011,12,28), Date(2012, 2,28))
    @test InterestRates.yearfractionvalue(dc, Date(2012, 3,28), Date(2012, 2,29)) == -InterestRates.yearfractionvalue(dc, Date(2012, 2,29), Date(2012, 3,28))

    # discount factor
    dt_curve = Date(2012,3,1)
    curve = InterestRates.IRCurve("dummy-thirty360", InterestRates.Thirty360(),
        InterestRates.SimpleCompounding(), InterestRates.StepFunction(), dt_curve,
        [1], [0.05])

    @test InterestRates.discountfactor(curve, Date(2012, 3,28)) == 1/(1+0.05 * ((28-1) + (3-3)*30 + (2012-2012)*360)/360)
    @test InterestRates.discountfactor(curve, Date(2012, 4,1)) == 1/(1+0.05 * 30/360)
    @test InterestRates.discountfactor(curve, Date(2012, 9,1)) == 1/(1+0.05 * 180/360)
    @test InterestRates.discountfactor(curve, Date(2013, 3,1)) == 1/(1+0.05 * 360/360)
end

@testset "Usage" begin
    include("usage.jl")
end

@testset "Benchmarks" begin
    include("perftests.jl")
end
