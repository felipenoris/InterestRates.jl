
# Performance tests for InterestRates module

println("Running perftests...")
println("######### SINGLE COMPUTATIONS ###########")
println("zero_rate for linear interpolation")
@time zero_rate(curve_b252_ec_lin, curve_get_date(curve_b252_ec_lin) + Dates.Day(5000))

println("ERF for FlatForward interpolation")
@time ERF(curve_ac360_cont_ff, dt_curve + Dates.Day(13))

println("zero_rate for FlatForward interpolation")
@time zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(13))

println("discountfactor for Linear interpolation on vector with simple compounding")
@time discountfactor(curve_ac365_simple_linear, mat_vec)

println("discountfactor on NS curve")
@time discountfactor(curve_NS, mat_vec)

println("discountfactor on Svensson curve")
@time discountfactor(curve_sven, mat_vec)

println("splinefit")
@time InterestRates.splinefit(vert_x, vert_y)

println("splineint")
@time InterestRates.splineint(sp, convert(Vector{Int}, 1:30))

println("######### MULTIPLE COMPUTATIONS ###########")

days_vec = [Dates.Day(i) for i=1:724]

println("Linear interpolation")
@time for i=1:1000 zero_rate(curve_b252_ec_lin, curve_get_date(curve_b252_ec_lin) + days_vec) end
@time for i=1:1000 ERF(curve_b252_ec_lin, curve_get_date(curve_b252_ec_lin) + days_vec) end
@time for i=1:1000 discountfactor(curve_b252_ec_lin, curve_get_date(curve_b252_ec_lin) + days_vec) end

days_vec = [Dates.Day(i) for i=1:8000]

println("FlatForward interpolation")
@time for i=1:1000 zero_rate(curve_ac360_cont_ff, curve_get_date(curve_ac360_cont_ff) + days_vec) end
@time for i=1:1000 ERF(curve_ac360_cont_ff, curve_get_date(curve_ac360_cont_ff) + days_vec) end
@time for i=1:1000 discountfactor(curve_ac360_cont_ff, curve_get_date(curve_ac360_cont_ff) + days_vec) end

println("Nelson Siegel Term Structure Model")
@time for i=1:1000 zero_rate(curve_NS, curve_get_date(curve_NS) + days_vec) end
@time for i=1:1000 ERF(curve_NS, curve_get_date(curve_NS) + days_vec) end
@time for i=1:1000 discountfactor(curve_NS, curve_get_date(curve_NS) + days_vec) end

println("Svensson Term Structure Model")
@time for i=1:1000 zero_rate(curve_sven, curve_get_date(curve_sven) + days_vec) end
@time for i=1:1000 ERF(curve_sven, curve_get_date(curve_sven) + days_vec) end
@time for i=1:1000 discountfactor(curve_sven, curve_get_date(curve_sven) + days_vec) end

println("Splines on Rates interpolation")
@time for i=1:1000 zero_rate(curve_spline_rates, curve_get_date(curve_spline_rates) + days_vec) end
@time for i=1:1000 ERF(curve_spline_rates, curve_get_date(curve_spline_rates) + days_vec) end
@time for i=1:1000 discountfactor(curve_spline_rates, curve_get_date(curve_spline_rates) + days_vec) end

println("Splines on Discount Factors")
@time for i=1:1000 zero_rate(curve_spline_discount, curve_get_date(curve_spline_discount) + days_vec) end
@time for i=1:1000 ERF(curve_spline_discount, curve_get_date(curve_spline_discount) + days_vec) end
@time for i=1:1000 discountfactor(curve_spline_discount, curve_get_date(curve_spline_discount) + days_vec) end

println("splinefit")
@time for i=1:1000 InterestRates.splinefit(vert_x, vert_y) end

println("splineint")
@time for i=1:1000 InterestRates.splineint(sp, convert(Vector{Int}, 1:8000)) end
