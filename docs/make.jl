using RefractiveIndex
using Documenter

DocMeta.setdocmeta!(RefractiveIndex, :DocTestSetup, :(using RefractiveIndex); recursive=true)

makedocs(;
    modules=[RefractiveIndex],
    authors="Alex Ames <alexander.m.ames@gmail.com> and contributors",
    repo="https://github.com/stillyslalom/RefractiveIndex.jl/blob/{commit}{path}#{line}",
    sitename="RefractiveIndex.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://stillyslalom.github.io/RefractiveIndex.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/stillyslalom/RefractiveIndex.jl",
)
