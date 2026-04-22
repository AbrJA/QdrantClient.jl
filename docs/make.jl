using Documenter, QdrantClient

makedocs(
    modules  = [QdrantClient],
    sitename = "QdrantClient.jl",
    format   = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    pages    = ["Home" => "index.md"],
)

deploydocs(
    repo = "github.com/AbrJA/QdrantClient.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing,
    push_preview = true,
)
