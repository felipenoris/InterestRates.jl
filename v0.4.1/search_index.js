var documenterSearchIndex = {"docs":
[{"location":"api/#API-Reference-1","page":"API Reference","title":"API Reference","text":"","category":"section"},{"location":"api/#","page":"API Reference","title":"API Reference","text":"InterestRates.zero_rate\nInterestRates.forward_rate\nInterestRates.discountfactor","category":"page"},{"location":"api/#InterestRates.zero_rate","page":"API Reference","title":"InterestRates.zero_rate","text":"zero_rate(curve, maturity)\n\nReturns the zero-coupon rate to maturity.\n\n\n\n\n\n","category":"function"},{"location":"api/#InterestRates.forward_rate","page":"API Reference","title":"InterestRates.forward_rate","text":"forward_rate(curve, forward_date, maturity)\n\nReturns the forward rate from a future date forward_date to maturity.\n\n\n\n\n\n","category":"function"},{"location":"api/#InterestRates.discountfactor","page":"API Reference","title":"InterestRates.discountfactor","text":"discountfactor(curve, maturity)\ndiscountfactor(curve, forward_date, maturity)\n\nReturns the discount factor to maturity. Or a forward discount factor from forward_date to maturity.\n\n\n\n\n\n","category":"function"},{"location":"#InterestRates.jl-1","page":"Home","title":"InterestRates.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Tools for Term Structure of Interest Rates calculation, aimed at the valuation of financial contracts, specially Fixed Income instruments.","category":"page"},{"location":"#Requirements-1","page":"Home","title":"Requirements","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Julia v1.0 or newer.","category":"page"},{"location":"#Installation-1","page":"Home","title":"Installation","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"From a Julia session, run:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using Pkg\n\njulia> Pkg.add(\"InterestRates\")","category":"page"},{"location":"#Concept-1","page":"Home","title":"Concept","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"A Term Structure of Interest Rates, also known as zero-coupon curve, is a function f(t) → y that maps a given maturity t onto the yield y of a bond that matures at t and pays no coupons (zero-coupon bond).","category":"page"},{"location":"#","page":"Home","title":"Home","text":"For instance, say the current price of a bond that pays exactly 10 in 1 year is 9.25. If one buys that bond for the current price and holds it until the maturity of the contract, that investor will gain 0.75, which represents 8.11% of the original price. That means that the bond is currently priced with a yield of 8.11% per year.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"It's not feasible to observe prices for each possible maturity. We can observe only a set of discrete data points of the yield curve. Therefore, in order to determine the entire term structure, one must choose an interpolation method, or a term structure model.","category":"page"},{"location":"#Data-Structure-for-Interest-Rate-Curve-1","page":"Home","title":"Data Structure for Interest Rate Curve","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"All yield curve calculation is built around AbstractIRCurve. The module expects that the concrete implementations of AbstractIRCurve provide the following methods:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"curve_get_name(curve::AbstractIRCurve) → String\ncurve_get_daycount(curve::AbstractIRCurve) → DayCountConvention\ncurve_get_compounding(curve::AbstractIRCurve) → CompoundingType\ncurve_get_method(curve::AbstractIRCurve) → CurveMethod\ncurve_get_date(curve::AbstractIRCurve) → Date, returns the date when the curve is observed.\ncurve_get_dtm(curve::AbstractIRCurve) → Vector{Int}, used for interpolation methods, returns daystomaturity on curve's daycount convention.\ncurve_get_zero_rates(curve::AbstractIRCurve) → Vector{Float64}, used for interpolation methods, parameters[i] returns yield for maturity dtm[i].\ncurve_get_model_parameters(curve::AbstractIRCurve) → Vector{Float64}, used for parametric methods, returns model's constant parameters.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"This package provides a default implementation of AbstractIRCurve interface, which is a database-friendly data type: IRCurve.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"mutable struct IRCurve <: AbstractIRCurve\n  name::String\n  daycount::DayCountConvention\n  compounding::CompoundingType\n  method::CurveMethod\n  date::Date\n  dtm::Vector{Int}\n  zero_rates::Vector{Float64}\n  parameters::Vector{Float64}\n  dict::Dict{Symbol, Any}   # holds pre-calculated values for optimization, or additional parameters.\n#...","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The type DayCountConvention sets the convention on how to count the number of days between dates, and also how to convert that number of days into a year fraction.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Given an initial date D1 and a final date D2, here's how the distance between D1 and D2 are mapped into a year fraction for each supported day count convention:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Actual360 : (D2 - D1) / 360\nActual365 : (D2 - D1) / 365\nBDays252 : bdays(D1, D2) / 252, where bdays is the business days","category":"page"},{"location":"#","page":"Home","title":"Home","text":"between D1 and D2 from BusinessDays.jl package.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The type CompoundingType sets the convention on how to convert a yield into an Effective Rate Factor.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Given a yield r and a maturity year fraction t, here's how each supported compounding type maps the yield to Effective Rate Factors:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"ContinuousCompounding : exp(r*t)\nSimpleCompounding : (1+r*t)\nExponentialCompounding : (1+r)^t","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The date field sets the date when the Yield Curve is observed. All zero rate calculation will be performed based on this date.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The fields dtm and zero_rates hold the observed market data for the yield curve, as discussed on Curve Methods section.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The field parameters holds parameter values for term structure models, as discussed on Curve Methods section.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"dict is avaliable for additional parameters, and to hold pre-calculated values for optimization.","category":"page"},{"location":"#Curve-Methods-1","page":"Home","title":"Curve Methods","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"This package provides the following curve methods.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Interpolation Methods","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Linear: provides Linear Interpolation on rates.\nFlatForward: provides Flat Forward interpolation, which is implemented as a Linear Interpolation on the log of discount factors.\nStepFunction: creates a step function around given data points.\nCubicSplineOnRates: provides natural cubic spline interpolation on rates.\nCubicSplineOnDiscountFactors: provides natural cubic spline interpolation on discount factors.\nCompositeInterpolation: provides support for different interpolation methods for: (1) extrapolation before first data point (before_first), (2) interpolation between the first and last point (inner), (3) extrapolation after last data point (after_last).","category":"page"},{"location":"#","page":"Home","title":"Home","text":"For Interpolation Methods, the field dtm holds the number of days between date and the maturity of the observed yield, following the curve's day count convention, which must be given in advance, when creating an instance of the curve. The field zero_rates holds the yield values for each maturity provided in dtm. All yields must be anual based, and must also be given in advance, when creating the instance of the curve.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Term Structure Models","category":"page"},{"location":"#","page":"Home","title":"Home","text":"NelsonSiegel: term structure model based on Nelson, C.R., and A.F. Siegel (1987), Parsimonious Modeling of Yield Curve, The Journal of Business, 60, 473-489.\nSvensson: term structure model based on Svensson, L.E. (1994), Estimating and Interpreting Forward Interest Rates: Sweden 1992-1994, IMF Working Paper, WP/94/114.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"For Term Structure Models, the field parameters holds the constants defined by each model, as described below. They must be given in advance, when creating the instance of the curve.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"For NelsonSiegel method, the array parameters holds the following parameters from the model:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"beta1 = parameters[1]\nbeta2 = parameters[2]\nbeta3 = parameters[3]\nlambda = parameters[4]","category":"page"},{"location":"#","page":"Home","title":"Home","text":"For Svensson method, the array parameters hold the following parameters from the model:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"beta1 = parameters[1]\nbeta2 = parameters[2]\nbeta3 = parameters[3]\nbeta4 = parameters[4]\nlambda1 = parameters[5]\nlambda2 = parameters[6]","category":"page"},{"location":"#Methods-hierarchy-1","page":"Home","title":"Methods hierarchy","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"As a summary, curve methods are organized by the following hierarchy.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"<<CurveMethod>>\n<<Interpolation>>\n<<DiscountFactorInterpolation>>\nCubicSplineOnDiscountFactors\nFlatForward\n<<RateInterpolation>>\nCubicSplineOnRates\nLinear\nStepFunction\nCompositeInterpolation\n<<Parametric>>\nNelsonSiegel\nSvensson","category":"page"},{"location":"#Usage-1","page":"Home","title":"Usage","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"using InterestRates\n\n# First, create a curve instance.\n\nvert_x = [11, 15, 50, 80] # for interpolation methods, represents the days to maturity\nvert_y = [0.10, 0.15, 0.14, 0.17] # yield values\n\ndt_curve = Date(2015,08,03)\n\nmycurve = InterestRates.IRCurve(\"dummy-simple-linear\", InterestRates.Actual365(),\n  InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,\n  vert_x, vert_y)\n\n# yield for a given maturity date\ny = zero_rate(mycurve, Date(2015,08,25))\n# 0.148\n\n# forward rate between two future dates\nfy = forward_rate(mycurve, Date(2015,08,25), Date(2015, 10, 10))\n# 0.16134333771591897\n\n# Discount factor for a given maturity date\ndf = discountfactor(mycurve, Date(2015,10,10))\n# 0.9714060637029466\n\n# Effective Rate Factor for a given maturity\nerf = ERF(mycurve, Date(2015,10,10))\n# 1.0294356164383562\n\n# Effective Rate for a given maturity\ner = ER(mycurve, Date(2015,10,10))\n# 0.029435616438356238","category":"page"},{"location":"#","page":"Home","title":"Home","text":"See runtests.jl for more examples.","category":"page"},{"location":"#Buffered-Curve-1","page":"Home","title":"Buffered Curve","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"A BufferedIRCurve buffers results of interest rate interpolations.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"You can create it by using InterestRates.BufferedIRCurve(source_curve) constructor, where source_courve is a given AbstractIRCurve.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The first time you ask for a rate, discount factor or effective factor for a given maturity, it will apply the source curve computation method. The second time you ask for any information for the same maturity, it will use the cached value.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Example:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"using InterestRates, BusinessDays\nconst ir = InterestRates\n\ncurve_date = Date(2017,3,2)\ndays_to_maturity = [ 1, 22, 83, 147, 208, 269,\n                     332, 396, 458, 519, 581, 711, 834]\nrates = [ 0.1213, 0.121875, 0.11359 , 0.10714 , 0.10255 , 0.100527,\n0.09935 , 0.09859 , 0.098407, 0.098737, 0.099036, 0.099909, 0.101135]\n\nmethod = ir.CompositeInterpolation(ir.StepFunction(), # before-first\n                                   ir.CubicSplineOnRates(), #inner\n                                   ir.FlatForward()) # after-last\n\ncurve_brl = ir.IRCurve(\"Curve BRL\", # name\n    ir.BDays252(:Brazil), # DayCountConvention\n    ir.ExponentialCompounding(), # CompoundingType\n    method, # interpolation method\n    curve_date, # base date\n    days_to_maturity,\n    rates);\n\nfixed_maturity = Date(2018,5,3)\n@elapsed discountfactor(curve_brl, fixed_maturity)\n# 0.178632414\n\nbuffered_curve_brl = ir.BufferedIRCurve(curve_brl)\ndiscountfactor(buffered_curve_brl, fixed_maturity) # stores in cache\n@elapsed discountfactor(buffered_curve_brl, fixed_maturity) # retrieves stored value in cache\n# 3.683e-5","category":"page"},{"location":"#Composite-Curves-1","page":"Home","title":"Composite Curves","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Warning: This is an experimental feature. The API may change in the future.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"InterestRates.CompositeIRCurve(curve_a, curve_b, ...) will return a composite curve.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Calling discountfactor or ERF on a composite curve will return the product of the results of these functions for each curve inside a composite curve.","category":"page"},{"location":"#Source-Code-1","page":"Home","title":"Source Code","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"The source code for this package is hosted at https://github.com/felipenoris/InterestRates.jl.","category":"page"},{"location":"#License-1","page":"Home","title":"License","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"The source code for the package InterestRates.jl is licensed under the MIT License.","category":"page"},{"location":"#Alternative-Packages-1","page":"Home","title":"Alternative Packages","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Ito.jl : https://github.com/aviks/Ito.jl\nFinancialMarkets.jl : https://github.com/imanuelcostigan/FinancialMarkets.jl","category":"page"}]
}
