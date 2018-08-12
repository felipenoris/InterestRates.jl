
# Performance tests for InterestRates module

println("Running perftests...")

using Test
using InterestRates

function run_perftests()

    dt_curve = Date(2015,08,08)

    vert_x = [11, 15, 19, 23, 25, 200, 500]
    vert_y = [0.10, 0.12, 0.20, 0.19, 0.21, 0.21, 0.22]
    NS_params = [0.1, 0.2, 0.3, 0.5]
    SVEN_params = [0.1, 0.2, 0.3, 0.4, 0.5, 0.8]

    days_vec = [Dates.Day(i) for i=1:1500]

    mat_vec = dt_curve + days_vec

    curve_linear = InterestRates.IRCurve("dummy-linear", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.Linear(), dt_curve,
        vert_x, vert_y)

    curve_flatforward = InterestRates.IRCurve("dummy-flatforward", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.FlatForward(), dt_curve,
        vert_x, vert_y)

    curve_ns = InterestRates.IRCurve("dummy-ns", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.NelsonSiegel(), dt_curve,
        NS_params)

    curve_sven = InterestRates.IRCurve("dummy-sven", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.Svensson(), dt_curve,
        SVEN_params)

    curve_spline_rates = InterestRates.IRCurve("dummy-spline_rates", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.CubicSplineOnRates(), dt_curve,
        vert_x, vert_y)

    curve_spline_df = InterestRates.IRCurve("dummy-spline_df", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.CubicSplineOnDiscountFactors(), dt_curve,
        vert_x, vert_y)

    curve_step = InterestRates.IRCurve("dummy-step", InterestRates.Actual360(),
        InterestRates.ExponentialCompounding(), InterestRates.StepFunction(), dt_curve,
        vert_x, vert_y)

    c_array = [curve_linear, curve_flatforward, curve_ns, curve_sven, curve_spline_rates, curve_spline_df, curve_step]

    # Warm up
    for c in c_array
        zero_rate(c, mat_vec)
        ERF(c, mat_vec)
        discountfactor(c, mat_vec)
    end

    # Check results
    for c in c_array
        zr = zero_rate(c, mat_vec)
        for i in 1:length(zr)
            @test zr[i] == zero_rate(c, mat_vec[i])
        end

        erf = ERF(c, mat_vec)
        for i in 1:length(erf)
            @test erf[i] == ERF(c, mat_vec[i])
        end

        df = discountfactor(c, mat_vec)
        for i in 1:length(df)
            @test df[i] == discountfactor(c, mat_vec[i])
        end
    end

    sp = InterestRates.splinefit(vert_x, vert_y)
    InterestRates.splineint(sp, convert(Vector{Int}, 1:30))

    # Perftests
    for c in c_array
        println("$(InterestRates.curve_get_method(c))")
        @time for i=1:100 zero_rate(c, mat_vec) end
        @time for i=1:100 ERF(c, mat_vec) end
        @time for i=1:100 discountfactor(c, mat_vec) end
    end
end

run_perftests()

println("Perftests end")
