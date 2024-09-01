
using Documenter
import InterestRates

makedocs(
    sitename = "InterestRates.jl",
    modules = [ InterestRates ],
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
    checkdocs=:none,
)

deploydocs(
    repo = "github.com/felipenoris/InterestRates.jl.git",
    target = "build",
)
