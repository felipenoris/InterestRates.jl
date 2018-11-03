
using InterestRates

# First, create a curve instance.

vert_x = [11, 15, 50, 80] # for interpolation methods, represents the days to maturity
vert_y = [0.10, 0.15, 0.14, 0.17] # yield values

dt_curve = Date(2015,08,03)

mycurve = InterestRates.IRCurve("dummy-simple-linear", InterestRates.Actual365(),
    InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,
    vert_x, vert_y)

# yield for a given maturity date
y = zero_rate(mycurve, Date(2015,08,25))
# 0.148

# forward rate between two future dates
fy = forward_rate(mycurve, Date(2015,08,25), Date(2015, 10, 10))
# 0.16134333771591897

# Discount factor for a given maturity date
df = discountfactor(mycurve, Date(2015,10,10))
# 0.9714060637029466

# Effective Rate Factor for a given maturity
erf = ERF(mycurve, Date(2015,10,10))
# 1.0294356164383562

# Effective Rate for a given maturity
er = ER(mycurve, Date(2015,10,10))
# 0.029435616438356238
