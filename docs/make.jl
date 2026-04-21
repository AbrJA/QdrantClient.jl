using Documenter, QdrantClient

makedocs(modules = [QdrantClient],
         sitename = "QdrantClient.jl",
         format = Documenter.HTML()
         )

deploydocs(
    repo = "github.com/AbrJA/QdrantClient.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing,
    push_preview = true,
)
