module RefractiveIndex

using Pkg.Artifacts
using YAML
using Interpolations
using HTTP.URIs: unescapeuri
using Unitful: @u_str, uparse, uconvert, ustrip, AbstractQuantity

import Base: getindex, show

export RefractiveMaterial

const RI_INFO_ROOT = Ref{String}()
const RI_LIB = Dict{Tuple{String, String, String}, NamedTuple{(:name, :path), Tuple{String, String}}}()
include("init.jl")
include("dispersionformulas.jl")

struct RefractiveMaterial{DF<:DispersionFormula}
    name::String
    reference::String
    comment::String
    dispersion::DF
    λrange::Tuple{Float64, Float64}
    specs::Dict{Symbol, Any}
end

const DISPERSIONFORMULAE = Dict(
    "formula 1" => Sellmeier,
    "formula 2" => Sellmeier2,
    "formula 3" => Polynomial,
    "formula 4" => RIInfo,
    "formula 5" => Cauchy,
    "formula 6" => Gases,
    "formula 7" => Herzberger,
    "formula 8" => Retro,
    "formula 9" => Exotic,
    "tabulated nk" => TabulatedNK,
    "tabulated n" => TabulatedN,
    "tabulated k" => TabulatedK,
)

function str2tuple(str)
    arr = parse.(Float64, split(str))
    ntuple(i -> arr[i], length(arr))
end

function DispersionFormula(data)
    DF = DISPERSIONFORMULAE[data[:type]]
    DF(str2tuple(data[:coefficients]))
end

function RefractiveMaterial(shelf, book, page)
    metadata = RI_LIB[(shelf, book, page)]
    path = joinpath(RI_INFO_ROOT[], "data", metadata.path)
    isfile(path) || @error "Specified material does not exist"
    yaml = YAML.load_file(path; dicttype=Dict{Symbol, Any})
    reference = get(yaml, :REFERENCES, "")
    comment = get(yaml, :COMMENTS, "")
    specs = get(yaml, :SPECS, Dict{Symbol, Any}())
    data = only(get(yaml, :DATA, Dict{Symbol, String}[]))
    DF = DispersionFormula(data)
    λrange = str2tuple(data[:wavelength_range])

    RefractiveMaterial(
        string(book, " ($(metadata.name))"),
        reference,
        comment,
        DF,
        λrange,
        specs
    )
end

function RefractiveMaterial(url::String)
    ue_url = unescapeuri(url)
    r = r"refractiveindex.info\/\?shelf=(?'shelf'\w+)&book=(?'book'.*)&page=(?'page'.*)"
    m = match(r, ue_url)
    isnothing(m) && @error "Invalid refractiveindex.info url"
    RefractiveMaterial(String(m["shelf"]),
                       String(m["book"]),
                       String(m["page"]))
end

show(io::IO, ::MIME"text/plain", m::RefractiveMaterial{DF}) where {DF} = show(io, m.name)
(m::RefractiveMaterial)(λ::Float64) = m.dispersion(λ)
(m::RefractiveMaterial)(λ::AbstractQuantity) = m(Float64(ustrip(uconvert(u"μm", λ))))
(m::RefractiveMaterial)(λ, dim::String) = m(λ*uparse(dim))
(m::RefractiveMaterial)(λ, ::Val{:nm}) = m(λ*u"nm")
(m::RefractiveMaterial)(λ, s::Symbol) = m(λ, Val(s))

end # module