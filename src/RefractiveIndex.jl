module RefractiveIndex

using HTTP.URIs: unescapeuri
using SnoopPrecompile
using DelimitedFiles: readdlm
using Serialization
using Scratch
using Pkg.Artifacts
using YAML
using Interpolations
using Unitful: @u_str, uparse, uconvert, ustrip, AbstractQuantity

import Base: getindex, show

export RefractiveMaterial

const RI_INFO_ROOT = Ref{String}()
const RI_LIB = Dict{Tuple{String, String, String}, NamedTuple{(:name, :path), Tuple{String, String}}}()
const DB_VERSION = "refractiveindex.info-database-2022-10-01"
const DB_INDEX_CACHE_PATH = joinpath(@get_scratch!("DB_VERSION"), "RI_index_cache.jls")

RI_INFO_ROOT[] = joinpath(artifact"refractiveindex.info", DB_VERSION, "database")

include("init.jl")
include("dispersionformulas.jl")

_init_cache()
copy!(RI_LIB, Serialization.deserialize(DB_INDEX_CACHE_PATH))

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
    if haskey(data, :coefficients)
        λrange = str2tuple(data[:wavelength_range])
        return DF(str2tuple(data[:coefficients])), λrange
    else
        raw = readdlm(IOBuffer(data[:data]), ' ', Float64)
        λrange = extrema(@view raw[:, 1])
        return DF(raw), λrange
    end
end

"""
    RefractiveMaterial(shelf, book, page)

Load the refractive index data for the material corresponding to the specified
shelf, book, and page within the [refractiveindex.info](https://refractiveindex.info/) database. The data
can be queried by calling the returned `RefractiveMaterial` object at a given wavelength.

# Examples
```julia-repl
julia> MgLiTaO3 = RefractiveMaterial("other", "Mg-LiTaO3", "Moutzouris-o")
"Mg-LiTaO3 (Moutzouris et al. 2011: n(o) 0.450-1.551 µm; 8 mol.% Mg)"

julia> MgLiTaO3(0.45) # default unit is microns
2.2373000025056826

julia> using Unitful

julia> MgLiTaO3(450u"nm") # auto-conversion from generic Unitful.jl length units
2.2373000025056826

julia> MgLiTaO3(450e-9, "m") # strings can be used to specify units (parsing is cached)
2.2373000025056826
```
"""
function RefractiveMaterial(shelf, book, page)
    metadata = RI_LIB[(shelf, book, page)]
    path = joinpath(RI_INFO_ROOT[], "data", metadata.path)
    isfile(path) || @error "Specified material does not exist"
    yaml = YAML.load_file(path; dicttype=Dict{Symbol, Any})
    reference = get(yaml, :REFERENCES, "")
    comment = get(yaml, :COMMENTS, "")
    specs = get(yaml, :SPECS, Dict{Symbol, Any}())
    data = get(yaml, :DATA, Dict{Symbol, String}[])
    if length(data) == 1
        DF, λrange = DispersionFormula(only(data))
        return RefractiveMaterial(
            string(book, " ($(metadata.name))"),
            reference,
            comment,
            DF,
            λrange,
            specs
        )
    else
        DFs = DispersionFormula.(data)
        return [RefractiveMaterial(
            string(book, " ($(metadata.name))"),
            reference,
            comment,
            DF,
            λrange,
            specs) for (DF, λrange) in DFs]
    end
end

"""
    RefractiveMaterial(url::String)

Extracts the shelf, book, and page from a refractiveindex.info URL and loads
the corresponding data from the local database (does not require an active internet connection). 

!!! warning 
    The refractiveindex.info website is regularly updated and may contain materials not yet
    available in the local copy of the database, which is updated on a roughly annual basis.
    Future versions of this package may allow these new entries to be automatically downloaded
    on demand.

# Examples
```julia-repl
julia> Ar = RefractiveMaterial("https://refractiveindex.info/?shelf=main&book=Ar&page=Peck-15C")
"Ar (Peck and Fisher 1964: n 0.47-2.06 µm; 15 °C)"

julia> Ar(532, "nm")
1.0002679711455778
```
"""
function RefractiveMaterial(url::String)
    ue_url = unescapeuri(url)
    r = r"refractiveindex.info\/\?shelf=(?'shelf'\w+)&book=(?'book'.*)&page=(?'page'.*)"
    m = match(r, ue_url)
    isnothing(m) && @error "Invalid refractiveindex.info url"
    RefractiveMaterial(String(m["shelf"]),
                       String(m["book"]),
                       String(m["page"]))
end


show(io::IO, ::MIME"text/plain", m::RefractiveMaterial{DF}) where {DF} = print(io, m.name, " - ", nameof(typeof(m.dispersion)))
(m::RefractiveMaterial)(λ::Float64) = m.dispersion(λ)
(m::RefractiveMaterial)(λ::AbstractQuantity) = m(ustrip(Float64, u"μm", λ))

_dim_to_micron(dim) = ustrip(Float64, u"μm", uparse(dim))
(m::RefractiveMaterial)(λ, dim::String) = m(λ*_dim_to_micron(dim))

(m::RefractiveMaterial{T})(λ::Float64) where {T <: Tabulated} = m.dispersion.n(λ)

include("precompile.jl")

end