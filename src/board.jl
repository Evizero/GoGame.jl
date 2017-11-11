mutable struct Board{A,R} <: AbstractBoard{A,R}
    state::A
    liberties::A
    ruleset::R
    player1_grps::Int
    player2_grps::Int
    turn::Int
    isplayer1::Bool
    numpass::Int
end

function Board(state::A, liberties::A=zeros(state), ruleset=ChineseRuleset()) where A<:AbstractArray
    @assert size(state) == size(liberties)
    Board(state, liberties, ruleset, 1, 2, 1, true, 0)
end

function Board(size::Int = 19, ruleset=ChineseRuleset())
    size ∈ (9, 13, 17, 19) || error("Illegal board size $size")
    state = zeros(Float32, size, size)
    Board(state, zeros(state), ruleset)
end

Base.convert(::Type{Array}, board::Board) = Array(board.state)

@inline Base.size(board::Board) = size(board.state)
@inline isturn(board, ::Type{Val{P1}}) where {P1} = P1 == board.isplayer1
@inline isplayer1(flag) = isodd(Int(flag))
@inline isplayer2(flag) = iseven(Int(flag))

function islegal(board::Board, ruleset::ChineseRuleset, ::Type{Val{P1}}, i, j) where P1
    h, w = size(board)
    @boundscheck (1 <= i <= h) && (1 <= j <= w)
    @inbounds flag = board.state[i,j]
    # check if occupied or forbidden by ko
    flag != 0 && return false
    # TODO: if any liberty, don't even bother checking further
    # TODO: check if neighbour group can get captured
    # TODO: check if suicide
    true
end

function pass(board::Board, p1::Type{Val{P1}}) where P1
    isturn(board, p1) || error("Currently not player $P1 turn")
    board.numpass += 1
    board.isplayer1 = P1 ? false : true
    # check two player pass in a row ?
    board.turn += 1
    board
end

function placestone(board::Board{<:AbstractArray{T}}, p1::Type{Val{P1}}, i, j) where {T, P1}
    h, w = size(board)
    isturn(board, p1) || error("Currently not player $(P1 ? 1 : 2) turn")
    islegal(board, board.ruleset, p1, i, j) || error("illegal move at ($i, $j)")

    # FIXME: this group counter business is ugly
    group_counter = P1 ? board.player1_grps : board.player2_grps
    group_counter = unsafe_placestone!(board.state, board.liberties, group_counter, p1, i, j)
    if P1 # <branch optimized out>
       board.player1_grps = group_counter
    else
       board.player2_grps = group_counter
    end

    # set next player and increase turn counter
    board.numpass = 0
    board.isplayer1 = P1 ? false : true
    board.turn += 1
    # TODO: check if game is over?
    board
end
