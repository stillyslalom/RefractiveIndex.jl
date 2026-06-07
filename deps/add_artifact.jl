# Database update procedure (run from the `deps` directory with this env active):
#   1. Bump the release date in the URL below and run this script to regenerate Artifacts.toml.
#   2. Update DB_VERSION in src/RefractiveIndex.jl to match the new release date.
#   3. Bump the package `version` in Project.toml.
# Latest releases: https://github.com/polyanskiy/refractiveindex.info-database/releases
using ArtifactUtils, Artifacts
add_artifact!(
    "../Artifacts.toml",
    "refractiveindex.info",
    "https://github.com/polyanskiy/refractiveindex.info-database/archive/v2026-05-24.tar.gz",
    # lazy=true, # need to use LazyArtifacts for this
    force=true,
    clear=false,
)
