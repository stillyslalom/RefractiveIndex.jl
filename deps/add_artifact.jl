using ArtifactUtils, Artifacts
add_artifact!(
    "../Artifacts.toml",
    "refractiveindex.info",
    "https://github.com/polyanskiy/refractiveindex.info-database/archive/v2023-10-04.tar.gz",
    # lazy=true, # need to use LazyArtifacts for this
    force=true,
    clear=false,
)
