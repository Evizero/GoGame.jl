__precompile__()
module GoGame

using Base: Cartesian, @propagate_inbounds
using StaticArrays
using Crayons

export

    ChineseRuleset,

    ArrayBoard,
    isturn,
    islegal,
    pass,
    placestone

abstract type Ruleset end

include("utils.jl")
include("board.jl")
include("chinese.jl")
include("arrayboard.jl")
include("io.jl")

end # module
