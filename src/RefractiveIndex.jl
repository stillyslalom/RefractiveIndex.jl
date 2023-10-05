module RefractiveIndex

using HTTP.URIs: unescapeuri
using PrecompileTools
using DelimitedFiles: readdlm
using Serialization
using Scratch
using Pkg.Artifacts
using YAML
# using Interpolations
# using Interpolations: deduplicate_knots!
using BasicInterpolators
using Unitful: @u_str, uparse, uconvert, ustrip, AbstractQuantity

import Base: getindex, show

export RefractiveMaterial, dispersion, extinction, showmetadata, specifications

const RI_INFO_ROOT = Ref{String}()
const RI_LIB = Dict{Tuple{String, String, String}, NamedTuple{(:name, :path), Tuple{String, String}}}()
const DB_VERSION = "refractiveindex.info-database-2023-10-04"
const DB_INDEX_CACHE_PATH = joinpath(@get_scratch!(DB_VERSION), "RI_index_cache.jls")

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
        raw = readdlm(IOBuffer(data[:data]), Float64)
        λrange = extrema(@view raw[:, 1])
        return DF(raw), λrange
    end
end

"""
    RefractiveMaterial(shelf, book, page)

Load the refractive index data for the material corresponding to the specified
shelf, book, and page within the [refractiveindex.info](https://refractiveindex.info/) database. The data
can be queried by calling the returned `RefractiveMaterial` object at a given wavelength.
In the case of database entries with multiple types of dispersion data (e.g. both 
raw dispersion data and dispersion formula coefficients), a vector of `RefractiveMaterial`s
is returned for each data type.

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

julia> Hikari_F1 = RefractiveMaterial("glass", "HIKARI-F", "F1")
2-element Vector{RefractiveMaterial}:
 HIKARI-F (F1) - Polynomial
 HIKARI-F (F1) - TabulatedK
```
"""
function RefractiveMaterial(shelf, book, page)
    metadata = RI_LIB[(shelf, book, page)]
    path = joinpath(RI_INFO_ROOT[], "data-nk", metadata.path)
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

julia> describe(Ar)
Name: Ar (Peck and Fisher 1964: n 0.47–2.06 µm; 15 °C)
Reference: E. R. Peck and D. J. Fisher. Dispersion of argon, <a href="https://doi.org/10.1364/JOSA.54.001362"><i>J. Opt. Soc. Am.</i> <b>54</b>, 1362-1364 (1964)</a>
Comments: 15 °C, 760 torr (101.325 kPa)
Dispersion Formula: Gases
Wavelength Range: (0.4679, 2.0587)
Specifications: Dict{Symbol, Any}(:temperature => "15 °C", :wavelength_vacuum => true, :pressure => "101325 Pa", :n_absolute => true)
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

"""
    showmetadata(rm::RefractiveMaterial)

Prints the metadata for the material `rm` to the terminal.

# Examples
```julia-repl
julia> Ar = RefractiveMaterial("main", "Ar", "Peck-15C")
Ar (Peck and Fisher 1964: n 0.47–2.06 µm; 15 °C) - Gases

julia> showmetadata(Ar)
Name: Ar (Peck and Fisher 1964: n 0.47–2.06 µm; 15 °C)
Reference: E. R. Peck and D. J. Fisher. Dispersion of argon, <a href="https://doi.org/10.1364/JOSA.54.001362"><i>J. Opt. Soc. Am.</i> <b>54</b>, 1362-1364 (1964)</a>
Comments: 15 °C, 760 torr (101.325 kPa)
Dispersion Formula: Gases
Wavelength Range: (0.4679, 2.0587)
Specifications: Dict{Symbol, Any}(:temperature => "15 °C", :wavelength_vacuum => true, :pressure => "101325 Pa", :n_absolute => true)
```
"""
function showmetadata(rm::RefractiveMaterial)
    println("Name: ", rm.name)
    println("Reference: ", rm.reference)
    println("Comments: ", rm.comment)
    println("Dispersion Formula: ", nameof(typeof(rm.dispersion)))
    println("Wavelength Range: ", rm.λrange)
    println("Specifications: ", rm.specs)
end

"""
    specifications(rm::RefractiveMaterial)

Returns a `Dict` containing the measurement specifications for the material `rm`.

# Examples
```julia-repl
julia> using Unitful

julia> specs = specifications(Ar)
Dict{Symbol, Any} with 4 entries:
  :temperature       => "15 °C"
  :wavelength_vacuum => true
  :pressure          => "101325 Pa"
  :n_absolute        => true

julia> T, P = [uparse(replace(specs[s], ' ' => '*')) for s in (:temperature, :pressure)]
2-element Vector{Quantity{Int64}}:
     15 °C
 101325 Pa
```
"""
function specifications(rm::RefractiveMaterial)
    rm.specs
end

"""
    dispersion(m::RefractiveMaterial, λ::Float64)

Returns the refractive index of the material `m` at the wavelength `λ` (in microns). An error is thrown if the material does not have refractive index data.
"""
dispersion(m::RefractiveMaterial, λ::Float64) = m.dispersion(λ)
dispersion(m::RefractiveMaterial{T}, λ::Float64) where {T <: Union{TabulatedN, TabulatedNK}} = m.dispersion.n(λ)
dispersion(m::RefractiveMaterial{TabulatedK}, λ::Float64) = throw(ArgumentError("Material does not have refractive index data"))

"""
    extinction(m::RefractiveMaterial, λ::Float64)

Returns the extinction coefficient of the material `m` at the wavelength `λ` (in microns). An error is thrown if the material does not have extinction data.
"""
extinction(m::RefractiveMaterial{T}, λ::Float64) where {T <: Union{TabulatedK, TabulatedNK}} = m.dispersion.k(λ)
extinction(m::RefractiveMaterial, λ::Float64) = throw(ArgumentError("Material does not have extinction data"))

(m::RefractiveMaterial)(λ::Float64) = dispersion(m, λ)
(m::RefractiveMaterial)(λ::AbstractQuantity) = dispersion(m, ustrip(Float64, u"μm", λ))

const DIM_TO_MICRON = Dict("nm" => 1e-3, "um" => 1.0, "mm" => 1e3, "cm" => 1e4, "m" => 1e6)
_to_micron(dim) = get!(DIM_TO_MICRON, dim) do
    ustrip(Float64, u"μm", 1.0*uparse(dim))::Float64
end
    
# ustrip(Float64, uparse(dim), 1.0u"μm")
(m::RefractiveMaterial)(λ, dim::String) = m(λ*_to_micron(dim))#*_dim_to_micron(dim))

# (m::RefractiveMaterial{T})(λ::Float64) where {T <: Union{TabulatedN, TabulatedNK}} = m.dispersion.n(λ)

include("precompile.jl")

end
