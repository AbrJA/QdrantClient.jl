using Documenter, Qdrant

makedocs(
    modules  = [Qdrant],
    sitename = "Qdrant.jl",
    checkdocs = :exports,
    format   = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    pages    = ["Home" => "index.md"],
)

deploydocs(
    repo = "github.com/AbrJA/Qdrant.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing,
    push_preview = true,
)
