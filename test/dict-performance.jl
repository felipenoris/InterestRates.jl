using Base.Test

abstract CurveContainer

type StaticContainer <: CurveContainer
	parameters_id::Vector{Int} # for interpolation methods, id stores days_to_maturity on curve's daycount convention.
	parameters_values::Vector{Float64}

	StaticContainer(parameters_id::Vector{Int}, parameters_values::Vector{Float64}) = begin
		
		if length(parameters_id) != length(parameters_values)
			error("parameters_id and parameters_values must have the same length")
		end

		if !issorted(parameters_id)
			error("parameters_id should be sorted before creating IRCurve instance")
		end

		new(parameters_id, parameters_values)
	end
end

type DictAnyContainer <: CurveContainer
	parameters::Dict{Any, Any}

	DictAnyContainer(parameters_id::Vector{Int}, parameters_values::Vector{Float64}) = begin
		
		if length(parameters_id) != length(parameters_values)
			error("parameters_id and parameters_values must have the same length")
		end

		if !issorted(parameters_id)
			error("parameters_id should be sorted before creating IRCurve instance")
		end

		d = Dict{Any, Any}()
		d["days_to_maturity"] = parameters_id
		d["zero_rates"] = parameters_values

		new(d)
	end
end

type DictSymbolContainer <: CurveContainer
	parameters::Dict{Symbol, Any}

	DictSymbolContainer(parameters_id::Vector{Int}, parameters_values::Vector{Float64}) = begin
		
		if length(parameters_id) != length(parameters_values)
			error("parameters_id and parameters_values must have the same length")
		end

		if !issorted(parameters_id)
			error("parameters_id should be sorted before creating IRCurve instance")
		end

		d = Dict{Symbol, Any}()
		d[:days_to_maturity] = parameters_id
		d[:zero_rates] = parameters_values

		new(d)
	end
end

get_dtm(c::DictSymbolContainer) = c.parameters[:days_to_maturity]::Vector{Int}
get_zero_rates(c::DictSymbolContainer) = c.parameters[:zero_rates]::Vector{Float64}

get_dtm(c::DictAnyContainer) = c.parameters["days_to_maturity"]::Vector{Int}
get_zero_rates(c::DictAnyContainer) = c.parameters["zero_rates"]::Vector{Float64}

get_dtm(c::StaticContainer) = c.parameters_id
get_zero_rates(c::StaticContainer) = c.parameters_values

#Xa, Ya, Xb, Yb = _interpolationpoints(curve.parameters_id, curve.parameters_values, x_out)
function _interpolationpoints(x::Vector{Int}, y::Vector{Float64}, x_out::Int)
	index_a::Int
	index_b::Int

	if x_out <= x[1]
		# Interpolation point is before first vertice
		# Slope will be determined by the 1st and 2nd vertices
		index_a = 1
		index_b = 2
	elseif x_out >= x[end]
		# Interpolation point is after last vertice
		# Slope will be determined by the last and last-1 vertices
		index_b = length(x)
		index_a = index_b - 1
	else
		# Inner point
		index_a =  findlast(a -> a < x_out, x) # last element before x_out on x
		index_b = findfirst(b -> b >=  x_out, x) # first element after x_out on x
	end
	
	Xa = x[index_a]
	Xb = x[index_b]
	Ya = y[index_a]
	Yb = y[index_b]
	
	return Xa, Ya, Xb, Yb
end

function run(c::CurveContainer, x_out_vec::Vector{Int})
	for i = 1:100000
		for x_out in x_out_vec
			index_a, index_b = _interpolationpoints(get_dtm(c), get_zero_rates(c), x_out)
		end
	end
end

const vert_x = [11, 15, 19, 23]
const vert_y = [0.10, 0.15, 0.20, 0.19]
const x_out_v = collect(1:100)

curve_static = StaticContainer(vert_x, vert_y)
curve_dict_any = DictAnyContainer(vert_x, vert_y)
curve_dict_sym = DictSymbolContainer(vert_x, vert_y)

run(curve_static, x_out_v)
println("static")
@time run(curve_static, x_out_v)

run(curve_dict_any, x_out_v)
println("dict any")
@time run(curve_dict_any, x_out_v)

run(curve_dict_sym, x_out_v)
println("dict sym")
@time run(curve_dict_sym, x_out_v)
