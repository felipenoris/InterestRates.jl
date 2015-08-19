
# Auxiliary functions for spline interpolation

type Spline{T}
	x::Vector{T}
	params::Vector{Float64}
	
	Spline{T}(x::Vector{T}, params::Vector{Float64}) = begin
		polynms_count = length(x) - 1
		if length(params) != polynms_count * 4 # each polynomial has 4 parameters
			error("params length $(length(params)) does not conform to the expected number of polynomials ($(polynms_count))")
		end
		new(x, params)
	end
end

# Spline interpolation
function splineint{T}(s::Spline{T}, x_out::T)
	poly_index::Int = 1
	
	if x_out > s.x[end]
		poly_index = length(s.x) - 1
	else
		while x_out > s.x[poly_index+1]
			poly_index += 1
		end
	end

	base_idx = (poly_index-1)*4
	#P1                       P2                    P3                     ...
	#1   2    3      4        5   6    7      8     9   10   11     12
	#a + bx + cx^2 + dx^3     a + bx + cx^2 + dx^3  a + bx + cx^2 + dx^3   ...
	return s.params[base_idx + 1] + s.params[base_idx + 2]*x_out + 
		s.params[base_idx + 3]*(x_out^2) + s.params[base_idx + 4]*(x_out^3)
end

function splineint{T}(s::Spline{T}, x_out::Vector{T})
	len = length(x_out)
	y_out = Array(Float64, len)
	for i in 1:len
		y_out[i] = splineint(s, x_out[i])
	end
	return y_out
end

function splinefit{T}(x_in::Vector{T}, y_in::Vector{Float64})
	#
	# TODO: optimize. See http://www.math.ntnu.no/emner/TMA4215/2008h/cubicsplines.pdf
	#
	points_count = length(x_in)
	if points_count != length(y_in)
		error("x_in and y_in doesn't conform on sizes.")
	end
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

		# Conditions of first order derivatives
		A[row, (i-2)*4 + 2] = 1.0
		A[row, (i-2)*4 + 3] = 2.0*x_in[i]
		A[row, (i-2)*4 + 4] = 3.0*(x_in[i]^2)
		A[row, (i-1)*4 + 2] = -1.0
		A[row, (i-1)*4 + 3] = -2.0*x_in[i]
		A[row, (i-1)*4 + 4] = -3.0*(x_in[i]^2)

		row += 1

		# Conditions of second order derivatives
		A[row, (i-2)*4 + 3] = 2.0
		A[row, (i-2)*4 + 4] = 6.0 * x_in[i]
		A[row, (i-1)*4 + 3] = -2.0
		A[row, (i-1)*4 + 4] = -6.0 * x_in[i]

		row += 1
	end

	# Conditions on natural cubic spline
	A[row, 3] = 2.0
	A[row, 4] = 6.0 * x_in[1]
	
	row += 1

	A[row, (points_count-2)*4 + 3] = 2.0
	A[row, (points_count-2)*4 + 4] = 6.0 * x_in[points_count]
	
	return Spline{eltype(x_in)}(x_in, A \ b)
end