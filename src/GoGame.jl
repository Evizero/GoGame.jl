__precompile__()
module GoGame

using Base: Cartesian, @propagate_inbounds
using StaticArrays
using Crayons

export

    # Rules
    ChineseRuleset,

    # Board types
    ArrayBoard,

    # info functions
    isturn,
    islegal,
    issuicide,
    isgameover,

    # action functions
    pass,
    placestone

abstract type Ruleset end

include("utils.jl")
include("board.jl")
include("chinese.jl")
include("arrayboard.jl")
include("io.jl")

end # module
