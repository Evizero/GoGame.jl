module GoGame

using Crayons

export

    Board,
    islegal,
    placestone,
    pass

abstract type Ruleset end

abstract type AbstractBoard{A<:AbstractArray,R<:Ruleset} end

include("chinese.jl")
include("board.jl")
include("io.jl")

end # module
