# RefractiveIndex

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://stillyslalom.github.io/RefractiveIndex.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://stillyslalom.github.io/RefractiveIndex.jl/dev)
[![Build Status](https://github.com/stillyslalom/RefractiveIndex.jl/workflows/CI/badge.svg)](https://github.com/stillyslalom/RefractiveIndex.jl/actions)

Provides an offline interface to [refractiveindex.info](http://refractiveindex.info).

### Examples
```
julia> MgLiTaO3 = RefractiveMaterial("other", "Mg-LiTaO3", "Moutzouris-o")
"Mg-LiTaO3 (Moutzouris et al. 2011: n(o) 0.450-1.551 µm; 8 mol.% Mg)"

julia> MgLiTaO3(0.45) # default unit is microns
2.2373000025056826

julia> using Unitful

julia> MgLiTaO3(450u"nm") # auto-conversion from generic Unitful.jl length units
2.2373000025056826

julia> MgLiTaO3(450e-9, "m") # strings can be used to specify units (parsing is cached)
2.2373000025056826

julia> Ar = RefractiveMaterial("https://refractiveindex.info/?shelf=main&book=Ar&page=Peck-15C")
"Ar (Peck and Fisher 1964: n 0.47-2.06 µm; 15 °C)"

julia> Ar(532, "nm")
1.0002679711455778
```