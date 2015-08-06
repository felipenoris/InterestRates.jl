
# Performance tests comparing different method dispatch implementations

using Base.Test

@enum ECompoundingType EContinuous=1 ESimple=2 EExponential=3

abstract TCompoundType

type TContinuous <: TCompoundType end
type TSimple <: TCompoundType end
type TExponential <: TCompoundType end

function ediscount_factor(compounding::ECompoundingType, r::Real, t::Real)
	if compounding == EContinuous
		return 1.0 / exp(r*t)
	elseif compounding == ESimple
		return 1.0 / (1 + r*t)
	elseif compounding == EExponential
		return 1.0 / ((1+r)^t)
	else
		error("Unknown compounding type $(compounding)")
	end
end

function vdiscount_factor(::Type{Val{EContinuous}}, r::Real, t::Real)
	return 1.0 / exp(r*t)
end

function vdiscount_factor(::Type{Val{ESimple}}, r::Real, t::Real)
	return 1.0 / (1 + r*t)
end

function vdiscount_factor(::Type{Val{EExponential}}, r::Real, t::Real)
	return 1.0 / ((1+r)^t)
end

function tdiscount_factor(::TContinuous, r::Real, t::Real)
	return 1.0 / exp(r*t)
end

function tdiscount_factor(::TSimple, r::Real, t::Real)
	return 1.0 / (1 + r*t)
end

function tdiscount_factor(::TExponential, r::Real, t::Real)
	return 1.0 / ((1+r)^t)
end

function tdiscount_factor(c::TCompoundType, r::Real, t::Real)
	error("not implemented for type $(typeof(c))")
end

Base.call(c::TContinuous, r::Real, t::Real) = 1.0 / exp(r*t)
Base.call(c::TSimple, r::Real, t::Real) = 1.0 / (1 + r*t)
Base.call(c::TExponential, r::Real, t::Real) = 1.0 / ((1+r)^t)

const _compound_functions = [ 
	(r::Real,t::Real) -> 1.0/exp(r*t),
	(r::Real,t::Real) -> 1.0/(1+r*t),
	(r::Real,t::Real) -> 1.0/((1+r)^t)
]

function rdiscount_factor(compounding::ECompoundingType, r::Real, t::Real)
	return _compound_functions[Int(compounding)](r,t)
end

function rdiscount_factor(c::Int64, r::Real, t::Real)
	return _compound_functions[c](r,t)
end

func_c = TContinuous()
func_s = TSimple()
func_e = TExponential()

# Continuous
ef_c = ediscount_factor(EContinuous, 0.15, 2.0)
vf_c = vdiscount_factor(Val{EContinuous}, 0.15, 2.0)
tf_c = tdiscount_factor(TContinuous(), 0.15, 2.0)
rf_c = rdiscount_factor(EContinuous, 0.15, 2.0)
rif_c = rdiscount_factor(1, 0.15, 2.0)
ff_c = func_c(0.15, 2.0)

# Simple
ef_s = ediscount_factor(ESimple, 0.15, 2.0)
vf_s = vdiscount_factor(Val{ESimple}, 0.15, 2.0)
tf_s = tdiscount_factor(TSimple(), 0.15, 2.0)
rf_s = rdiscount_factor(ESimple, 0.15, 2.0)
rif_s = rdiscount_factor(2, 0.15, 2.0)
ff_s = func_s(0.15, 2.0)

# Exponential
ef_e = ediscount_factor(EExponential, 0.15, 2.0)
vf_e = vdiscount_factor(Val{EExponential}, 0.15, 2.0)
tf_e = tdiscount_factor(TExponential(), 0.15, 2.0)
rf_e = rdiscount_factor(EExponential, 0.15, 2.0)
rif_e = rdiscount_factor(3, 0.15, 2.0)
ff_e = func_e(0.15, 2.0)

@test ef_c == vf_c == tf_c == rf_c == rif_c == ff_c
@test ef_s == vf_s == tf_s == rf_s == rif_s == ff_s
@test ef_e == vf_e == tf_e == rf_e == rif_e == ff_e

#EContinuous=1 ESimple=2 EExponential=3
println("enums with switch code")
@time begin
		for i = 1:10000000
			ediscount_factor(EContinuous, 0.15, 2.0)
			ediscount_factor(ESimple, 0.15, 2.0)
			ediscount_factor(EExponential, 0.15, 2.0)
		end
	end

println("Dispatch via Val Type")
@time begin
		for i = 1:10000000
			vdiscount_factor(Val{EContinuous}, 0.15, 2.0)
			vdiscount_factor(Val{ESimple}, 0.15, 2.0)
			vdiscount_factor(Val{EExponential}, 0.15, 2.0)
		end
	end

println("Dispatch via Const Val Type")
const cValCont = Val{EContinuous}
const cValSim = Val{ESimple}
const cValExp = Val{EExponential}
@time begin
		for i = 1:10000000
			vdiscount_factor(cValCont, 0.15, 2.0)
			vdiscount_factor(cValSim, 0.15, 2.0)
			vdiscount_factor(cValExp, 0.15, 2.0)
		end
	end

println("Dispatch via Type")
@time begin
		for i = 1:10000000
			tdiscount_factor(TContinuous(), 0.15, 2.0)
			tdiscount_factor(TSimple(), 0.15, 2.0)
			tdiscount_factor(TExponential(), 0.15, 2.0)
		end
	end

println("Raw function vector dispatch")
@time begin
		for i = 1:10000000
			rdiscount_factor(EContinuous, 0.15, 2.0)
			rdiscount_factor(ESimple, 0.15, 2.0)
			rdiscount_factor(EExponential, 0.15, 2.0)
		end
	end

println("Raw function vector dispatch with integers")
@time begin
		for i = 1:10000000
			rdiscount_factor(1, 0.15, 2.0)
			rdiscount_factor(2, 0.15, 2.0)
			rdiscount_factor(3, 0.15, 2.0)
		end
	end

println("Functors")
fc = TContinuous()
fs = TSimple()
fe = TExponential()

@time begin
		for i = 1:10000000
			fc(0.15, 2.0)
			fs(0.15, 2.0)
			fe(0.15, 2.0)
		end
	end

println("Const Functors")
const cfc = TContinuous()
const cfs = TSimple()
const cfe = TExponential()

@time begin
		for i = 1:10000000
			cfc(0.15, 2.0)
			cfs(0.15, 2.0)
			cfe(0.15, 2.0)
		end
	end