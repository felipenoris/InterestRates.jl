
# Auxiliary functions for natural cubic spline interpolation

# Stores parameters for fitted spline polynomials
mutable struct Spline{T}
    x::Vector{T} # (x, y) are the original points
    y::Vector{Float64}
    params::Vector{Float64} # stores parameters for polynomials. [ a1, b1, c1, d1, a2, b2, c2, d2 ...]

    function Spline(x::Vector{T}, y::Vector{Float64}, params::Vector{Float64}) where {T}
        polynms_count = length(x) - 1
        @assert length(params) == polynms_count * 4 "params length $(length(params)) does not conform to the expected number of polynomials ($(polynms_count))" # each polynomial has 4 parameters
        return new{T}(x, y, params)
    end
end

# Performs natural cubic spline interpolation
function splineint(s::Spline{T}, x_out::Number) where {T<:Number}
    
    if x_out > s.x[end]
        # Extrapolation after last point
        n = length(s.x)
        x = x_out - s.x[n]
        dxn = s.x[n] - s.x[n-1]
        i = 4*(n-1)
        b = s.params[i-2] + 2*s.params[i-1]*dxn + 3*s.params[i]*dxn*dxn
        return s.y[n] + b*x
    
    elseif x_out < s.x[1]
        # Extrapolation before first point
        return s.params[1] + s.params[2]*(x_out - s.x[1])
    
    else
        # Find polynomial
        i = 1
        while x_out > s.x[i+1]
            i = i + 1
        end
        
        x = x_out - s.x[i]
        a = s.params[4*i - 3]
        b = s.params[4*i - 2]
        c = s.params[4*i - 1]
        d = s.params[4*i]
        return a + b*x + c*x*x + d*x*x*x
    end
end

# Performs natural cubic spline interpolation
function splineint(s::Spline{T1}, x_out::Vector{T2}) :: Vector{Float64} where {T1, T2}
    len = length(x_out)
    y_out = Vector{Float64}(undef, len)
    for i in 1:len
        y_out[i] = splineint(s, x_out[i])
    end
    return y_out
end

# Build a Spline object by fitting 3rd order polynomials around points (x_in, y_in)
function splinefit(x_in::Vector{T}, y_in::Vector{Float64}) :: Spline{T} where {T}
    X = x_in
    Y = y_in

    n = length(x_in)
    @assert n == length(y_in) "x_in and y_in doesn't conform on sizes."

    H = [X[i+1] - X[i] for i in 1:(n-1)]  # i in [0,...,n-2]
    A = Y
    Alpha = [(3/H[i])*(A[i+1] - A[i]) - (3/H[i-1])*(A[i] - A[i-1]) for i in 2:(n-1)]
    Alpha = [0; Alpha]

    L = ones(n)
    Mu = zeros(n)
    Z = zeros(n)
    B = zeros(n)
    C = zeros(n)
    D = zeros(n)

    for i in 2:n-1
        L[i] = 2 * (X[i+1] -  X[i-1]) - H[i-1] * Mu[i-1]
        Mu[i] = H[i] / L[i]
        Z[i] = (Alpha[i] - H[i-1]*Z[i-1]) /  L[i]
    end

    for i in n-1:-1:1
        C[i] = Z[i] - Mu[i] * C[i+1]
        B[i] = (A[i+1] - A[i]) / H[i] - H[i] * (C[i+1] + 2*C[i]) / 3
        D[i] = (C[i+1] - C[i]) / (3*H[i])
    end

    spline_params = reduce(vcat, [[A[i], B[i], C[i], D[i]] for i in 1:n-1])
    return Spline(x_in, y_in, spline_params)
end
