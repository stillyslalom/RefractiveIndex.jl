using ArtifactUtils, Artifacts
add_artifact!(
    "../Artifacts.toml",
    "refractiveindex.info",
    "https://github.com/polyanskiy/refractiveindex.info-database/archive/v2020-01-19.tar.gz",
    # lazy=true, # need to use LazyArtifacts for this
    force=true,
    clear=false,
)