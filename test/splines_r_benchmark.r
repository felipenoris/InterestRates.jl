library(splines)

x_in = c(11, 15, 19, 23, 25)
y_in = c(0.1, 0.12, 0.2, 0.22, 0.2)
x_out = 1:30

ispl <- interpSpline( as.numeric(x_in), y_in)
resultado <- predict(ispl, x_out)

#> source('~/.active-rstudio-document')
#> ispl
#polynomial representation of spline for y_in ~ as.numeric(x_in)
#constant  linear quadratic      cubic
#11     0.10  0.0115   0.00000  0.0000625
#15     0.15  0.0145   0.00075 -0.0003125
#19     0.20  0.0055  -0.00300  0.0002500
#23     0.19 -0.0065   0.00000  0.0000000
#> x_out
#[1]  5 10 11 12 14 15 16 17 18 19 20 22 23 25 30
#> resultado
#$x
#[1]  5 10 11 12 14 15 16 17 18 19 20 22 23 25 30

#$y
#[1] 0.0310000 0.0885000 0.1000000 0.1115625 0.1361875 0.1500000 0.1649375 0.1795000 0.1918125 0.2000000 0.2027500 0.1962500
#[13] 0.1900000 0.1770000 0.1445000

#attr(,"class")
#[1] "xyVector"