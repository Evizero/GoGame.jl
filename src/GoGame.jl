__precompile__()
module GoGame

using Base.Cartesian
using Crayons

export

    Board,
    islegal,
    placestone,
    pass

abstract type Ruleset end

abstract type AbstractBoard{A<:AbstractArray,R<:Ruleset} end

include("chinese.jl")
include("array.jl")
include("board.jl")
include("io.jl")

end # module
