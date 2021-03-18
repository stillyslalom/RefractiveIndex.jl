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

const ITP_TYPE = typeof(LinearInterpolation(sort(rand(2)), zeros(2)))

struct TabulatedNK <: Tabulated
    n::ITP_TYPE
    k::ITP_TYPE
end

function TabulatedNK(raw::Matrix{Float64})
    λ = raw[:, 1]
    n = raw[:, 2]
    k = raw[:, 3]
    TabulatedNK(LinearInterpolation(λ, n), LinearInterpolation(λ, k))
end

struct TabulatedN <: Tabulated
    n::ITP_TYPE
end

function TabulatedN(raw::Matrix{Float64})
    λ = raw[:, 1]
    n = raw[:, 2]
    TabulatedN(LinearInterpolation(λ, n))
end

struct TabulatedK <: Tabulated
    k::ITP_TYPE
end

function TabulatedK(raw::Matrix{Float64})
    λ = raw[:, 1]
    k = raw[:, 2]
    TabulatedK(LinearInterpolation(λ, k))
end