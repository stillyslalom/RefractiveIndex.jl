abstract type DispersionFormula end

getindex(d::DispersionFormula, i) = getindex(d.coefs, i)

struct Sellmeier{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Sellmeier{N})(λ) where {N}
    rhs = c[1]
    for i = 2:2:N
        rhs += c[i]*λ^2 / (λ^2 - c[i+1]^2)
    end
    return sqrt(rhs + 1)
end

struct Sellmeier2{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Sellmeier2{N})(λ) where {N}
    rhs = c[1]
    for i = 2:2:N
        rhs += c[i]*λ^2 / (λ^2 - c[i+1])
    end
    return sqrt(rhs + 1)
end

struct Polynomial{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Polynomial{N})(λ) where {N}
    rhs = c[1]
    for i = 2:2:N
        rhs += c[i]*λ^c[i+1]
    end
    return sqrt(rhs)
end

struct RIInfo{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::RIInfo{N})(λ) where {N}
    rhs = c[1]
    for i = 2:4:min(N, 9)
        rhs += (c[i]*λ^c[i+1]) / (λ^2 - c[i+2]^c[i+3])
    end
    for i = 10:2:N
        rhs += c[i]*λ^c[i+1]
    end
    return sqrt(rhs)
end

struct Cauchy{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Cauchy{N})(λ) where {N}
    rhs = c[1]
    for i = 2:2:N
        rhs += c[i]*λ^c[i+1]
    end
    return rhs
end

struct Gases{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Gases{N})(λ) where {N}
    rhs = c[1]
    for i = 2:2:N
        rhs += c[i] / (c[i+1] - 1/λ^2)
    end
    return rhs + 1
end

struct Herzberger{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Herzberger{N})(λ) where {N}
    rhs = c[1]
    rhs += c[2] / (λ^2 - 0.028)
    rhs += c[3] * (1/(λ^2 - 0.028))^2
    for i = 4:N
        pow = 2*(i - 3)
        rhs += c[i]*λ^pow
    end
    return rhs
end

struct Retro{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Retro{N})(λ) where {N}
    rhs = c[1] + c[2]*λ^2 / (λ^2 - c[3]) + c[4]*λ^2
    return sqrt((-2rhs - 1) / (rhs - 1))
end

struct Exotic{N} <: DispersionFormula
    coefs::NTuple{N,Float64}
end

function (c::Exotic{N})(λ) where {N}
    rhs = c[1] + c[2]/(λ^2 - c[3]) + c[4]*(λ - c[5]) / ((λ - c[5])^2 + c[6])
    return sqrt(rhs)
end

abstract type Tabulated <: DispersionFormula end

# _linear_itp(knots, values) = extrapolate(interpolate((deduplicate_knots!(knots),), values, Gridded(Linear())), Throw())
# const ITP_TYPE = typeof(_linear_itp([1.0, 2.0], [1.0, 2.0]))
_linear_itp(knots, values) = LinearInterpolator(knots, values, WeakBoundaries())
const ITP_TYPE = LinearInterpolator{Float64, WeakBoundaries}

function _fix_sorting(raw)
    # several entries are not sorted by wavelength, so we need to sort them
    if !issorted(@views raw[:, 1])
        raw = sortslices(raw, dims=1, by=first)
    end

    # workaround for two bad entries with only one wavelength:
    # ("other", "CR-39", "poly") => (name = "Polymer; n 0.58929 µm", path = "other/commercial plastics/CR-39/poly.yml")
    # ("other", "CR-39", "mono") => (name = "Monomer; n 0.58929 µm", path = "other/commercial plastics/CR-39/mono.yml")
    if size(raw, 1) == 1
        raw = [raw; raw]
    end

    return raw
end

struct TabulatedNK <: Tabulated
    n::ITP_TYPE
    k::ITP_TYPE
end

function TabulatedNK(raw::Matrix{Float64})
    raw = _fix_sorting(raw)
    λ = raw[:, 1]
    n = raw[:, 2]
    k = raw[:, 3]
    TabulatedNK(_linear_itp(λ, n), _linear_itp(λ, k))
end

struct TabulatedN <: Tabulated
    n::ITP_TYPE
end

function TabulatedN(raw::Matrix{Float64})
    raw = _fix_sorting(raw)
    λ = raw[:, 1]
    n = raw[:, 2]
    TabulatedN(_linear_itp(λ, n))
end

struct TabulatedK <: Tabulated
    k::ITP_TYPE
end

function TabulatedK(raw::Matrix{Float64})
    raw = _fix_sorting(raw)
    λ = raw[:, 1]
    k = raw[:, 2]
    TabulatedK(_linear_itp(λ, k))
end
