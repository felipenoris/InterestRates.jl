
# Auxiliary functions for natural cubic spline interpolation

# Stores parameters for fitted spline polynomials
mutable struct Spline{T}
    x::Vector{T} # (x, y) are the original points
    y::Vector{Float64}
    params::Vector{Float64} # stores parameters for polynomials. [ a1, b1, c1, d1, a2, b2, c2, d2 ...]

    function Spline{T}(x::Vector{T}, y::Vector{Float64}, params::Vector{Float64}) where {T}
        polynms_count = length(x) - 1
        @assert length(params) == polynms_count * 4 "params length $(length(params)) does not conform to the expected number of polynomials ($(polynms_count))" # each polynomial has 4 parameters
        new(x, y, params)
    end
end

# Given a polinomial index, returns the indexer of the last parameter before the first parameter of the referenced polinomial
_base_param_index_(poly_index::Int) = (poly_index-1)*4

# Performs natural cubic spline interpolation
function splineint(s::Spline{T}, x_out::T) where {T}
    local poly_index::Int = 1
    local base_idx::Int

    if x_out > s.x[end]
        # Extrapolation after last point
        poly_index = length(s.x) - 1
        base_idx = _base_param_index_(poly_index)
        return (x_out - s.x[end])*(s.params[base_idx + 2] + 2*s.params[base_idx + 3]*s.x[end] + 3*s.params[base_idx + 4]*(s.x[end]^2)) + s.y[end]
    elseif x_out < s.x[1]
        # Extrapolation before first point
        base_idx = 0
        return (x_out - s.x[1])*(s.params[base_idx + 2] + 2*s.params[base_idx + 3]*s.x[1] + 3*s.params[base_idx + 4]*(s.x[1]^2)) + s.y[1]
    else
        # Interplation
        while x_out > s.x[poly_index+1]
            poly_index += 1
        end

        base_idx = _base_param_index_(poly_index)

        #P1                       P2                    P3                     ...
        #1   2    3      4        5   6    7      8     9   10   11     12
        #a + bx + cx^2 + dx^3     a + bx + cx^2 + dx^3  a + bx + cx^2 + dx^3   ...
        return s.params[base_idx + 1] + s.params[base_idx + 2]*x_out +
            s.params[base_idx + 3]*(x_out^2) + s.params[base_idx + 4]*(x_out^3)
    end
end

# Performs natural cubic spline interpolation
function splineint(s::Spline{T}, x_out::Vector{T}) where {T}
    len = length(x_out)
    y_out = Vector{Float64}(undef, len)
    for i in 1:len
        y_out[i] = splineint(s, x_out[i])
    end
    return y_out
end

# Build a Spline object by fitting 3rd order polynomials around points (x_in, y_in)
function splinefit(x_in::Vector{T}, y_in::Vector{Float64}) where {T}
    #
    # TODO: optimize. See http://www.math.ntnu.no/emner/TMA4215/2008h/cubicsplines.pdf
    #
    points_count = length(x_in)
    @assert points_count == length(y_in) "x_in and y_in doesn't conform on sizes."
    matrix_n = 4*(points_count-1) # the main matrix is a square matrix matrix_n by matrix_n

    A = zeros(matrix_n, matrix_n)
    b = zeros(matrix_n)

    # Known values for polys

    # First Point
    A[1,1] = 1.0
    A[1,2] = x_in[1]
    A[1,3] = x_in[1]^2
    A[1,4] = x_in[1]^3
    b[1] = y_in[1]

    # Last Point
    base_idx = 4*(points_count - 2)
    A[2, base_idx + 1] = 1.0
    A[2, base_idx + 2] = x_in[points_count]
    A[2, base_idx + 3] = x_in[points_count]^2
    A[2, base_idx + 4] = x_in[points_count]^3
    b[2] = y_in[points_count]

    # Inner Points
    row = 3
    for i in 2:(points_count-1)
        # Connecting to left poly
        A[row, (i-2)*4 + 1] = 1.0
        A[row, (i-2)*4 + 2] = x_in[i]
        A[row, (i-2)*4 + 3] = x_in[i]^2
        A[row, (i-2)*4 + 4] = x_in[i]^3
        b[row] = y_in[i]

        row += 1

        # Connecting to right poly
        A[row, (i-1)*4 + 1] = 1.0
        A[row, (i-1)*4 + 2] = x_in[i]
        A[row, (i-1)*4 + 3] = x_in[i]^2
        A[row, (i-1)*4 + 4] = x_in[i]^3
        b[row] = y_in[i]

        row += 1

        # Conditions on first order derivatives
        A[row, (i-2)*4 + 2] = 1.0
        A[row, (i-2)*4 + 3] = 2.0*x_in[i]
        A[row, (i-2)*4 + 4] = 3.0*(x_in[i]^2)
        A[row, (i-1)*4 + 2] = -1.0
        A[row, (i-1)*4 + 3] = -2.0*x_in[i]
        A[row, (i-1)*4 + 4] = -3.0*(x_in[i]^2)

        row += 1

        # Conditions on second order derivatives
        A[row, (i-2)*4 + 3] = 2.0
        A[row, (i-2)*4 + 4] = 6.0 * x_in[i]
        A[row, (i-1)*4 + 3] = -2.0
        A[row, (i-1)*4 + 4] = -6.0 * x_in[i]

        row += 1
    end

    # Conditions for natural cubic spline
    A[row, 3] = 2.0
    A[row, 4] = 6.0 * x_in[1]

    row += 1

    A[row, (points_count-2)*4 + 3] = 2.0
    A[row, (points_count-2)*4 + 4] = 6.0 * x_in[points_count]

    return Spline{eltype(x_in)}(x_in, y_in, A \ b)
end
