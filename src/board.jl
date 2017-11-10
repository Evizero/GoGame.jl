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
@inline isturn(board, ::Type{Val{P}}) where {P} = P == board.isplayer1
@inline isplayer1(flag) = isodd(Int(flag))
@inline isplayer2(flag) = iseven(Int(flag))

function islegal(board::Board, ruleset::ChineseRuleset, ::Type{Val{P1}}, i, j) where P1
    h, w = size(board)
    @boundscheck (1 <= i <= h) && (1 <= j <= w)
    @inbounds flag = board.state[i,j]
    # check if occupied or forbidden by ko
    flag != 0 && return false
    # if any liberty, don't even bother checking further
    # check if neighbour group can get captured
    # check if suicide
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

function getgroup(board::Board{<:AbstractArray{T}}, ::Type{Val{P}}, i, j) where {T,P}
    h, w = size(board)
    if (1 > i) | (i > h) | (1 > j) | (j > w)
        return Nullable{T}(), Nullable{T}()
    end
    @inbounds flag = board.state[i,j]
    if P
        ifelse(flag <= 0,
               (Nullable{T}(),Nullable{T}()),
               ifelse(isplayer1(flag), (Nullable{T}(flag),Nullable{T}()), (Nullable{T}(),Nullable{T}(flag))))
    else
        ifelse(flag <= 0,
               (Nullable{T}(),Nullable{T}()),
               ifelse(isplayer2(flag), (Nullable{T}(flag),Nullable{T}()), (Nullable{T}(),Nullable{T}(flag))))
    end
end

function decreaseliberties!(board::Board{<:AbstractArray{T}}, i, j) where T
    h, w = size(board)
    if (1 > i) | (i > h) | (1 > j) | (j > w)
        return board
    end
    @inbounds flag = board.state[i,j]
    @inbounds liberties = board.liberties[i,j]
    @inbounds board.liberties[i,j] = ifelse(flag > 0, liberties - T(1), liberties)
    board
end

function replacegroups!(board::Board{<:AbstractArray{T}}, old1::T, old2::T, old3::T, old4::T, new::T) where T
    @inbounds for I in eachindex(board.state)
        val = board.state[I]
        board.state[I] = ifelse(
            val == zero(T), val, # don't replace empty intersections
            ifelse((val == old1) | (val == old2) | (val == old3) | (val == old4), new, val)
        )
    end
    board
end

function placestone(board::Board{<:AbstractArray{T}}, p1::Type{Val{P1}}, i, j) where {T, P1}
    isturn(board, p1) || error("Currently not player $(P1 ? 1 : 2) turn")
    islegal(board, board.ruleset, p1, i, j) || error("illegal move at ($i, $j)")
    ZERO = zero(T)
    board.numpass = 0
    # see how many friendly stones are adjacent
    up_friend,    up_enemy    = getgroup(board, p1, i+1, j)
    down_friend,  down_enemy  = getgroup(board, p1, i-1, j)
    left_friend,  left_enemy  = getgroup(board, p1, i, j-1)
    right_friend, right_enemy = getgroup(board, p1, i, j+1)
    num_enemies = 4 - isnull(up_enemy) - isnull(down_enemy) - isnull(left_enemy) - isnull(right_enemy)
    num_friends = 4 - isnull(up_friend) - isnull(down_friend) - isnull(left_friend) - isnull(right_friend)
    num_liberties = 4 - num_friends - num_enemies
    if num_friends == 0
        # no friendly stone around: create new group
        if P1
            flag = T(board.player1_grps)
            @inbounds board.state[i,j] = flag
            board.player1_grps += 2
        else
            flag = T(board.player2_grps)
            @inbounds board.state[i,j] = flag
            board.player2_grps += 2
        end
        @inbounds board.liberties[i,j] = num_liberties
    elseif num_friends == 1
        # only one friendly stone around: join its group
        flag = get(up_friend,ZERO) + get(down_friend,ZERO) + get(left_friend,ZERO) + get(right_friend,ZERO)
        @inbounds board.state[i,j] = flag
        @inbounds board.liberties[i,j] = num_liberties
    else
        # multiple friendly stones around: create new group and absorb all
        if P1
            flag = T(board.player1_grps)
            replacegroups!(board, get(up_friend,ZERO), get(down_friend,ZERO), get(left_friend,ZERO), get(right_friend,ZERO), flag)
            @inbounds board.state[i,j] = flag
            board.player1_grps += 2
        else
            flag = T(board.player2_grps)
            replacegroups!(board, get(up_friend,ZERO), get(down_friend,ZERO), get(left_friend,ZERO), get(right_friend,ZERO), flag)
            @inbounds board.state[i,j] = flag
            board.player2_grps += 2
        end
        @inbounds board.liberties[i,j] = num_liberties
        # liberties of friends are updated later
    end
    if liberties < 4
        drcre
        # update surrounding liberties

    else
    # TODO: check for capture and apply

    end
    # set next player and increase turn counter
    board.isplayer1 = P1 ? false : true
    board.turn += 1
    board
end

