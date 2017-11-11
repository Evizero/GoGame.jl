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

function getgroup(board::Board{<:AbstractArray{T}}, ::Type{Val{P1}}, i, j) where {T,P1}
    h, w = size(board)
    # FIXME: get rid of this branch somehow?
    if (1 > i) | (i > h) | (1 > j) | (j > w)
        return Nullable{T}(), Nullable{T}()
    end
    @inbounds flag = board.state[i,j]
    # if the current position is empty we return two null
    # otherwise we return the flag as friend or enemy,
    # depending on which player we are
    ifelse(flag <= 0, (Nullable{T}(),Nullable{T}()),
           ifelse(P1 ? isplayer1(flag) : isplayer2(flag), # TODO: <branch optimized out> ?
                  (Nullable{T}(flag),Nullable{T}()),
                  (Nullable{T}(),Nullable{T}(flag))))
end

function decreaseliberties!(board::Board{<:AbstractArray{T}}, i, j) where T
    h, w = size(board)
    # FIXME: get rid of this branch somehow?
    if (1 > i) | (i > h) | (1 > j) | (j > w)
        return board
    end
    @inbounds flag = board.state[i,j]
    @inbounds liberties = board.liberties[i,j]
    @inbounds board.liberties[i,j] = ifelse(flag > 0, liberties - T(1), liberties)
    board
end

function groupliberties(board::Board{<:AbstractArray{T}}, flags::NTuple{4,T}) where T
    # unpack group flags (some flags may be 0, indicating empty space)
    @nexprs 4 k -> (flag_k = flags[k])
    # initialize total-liberties counter for each (potential) group
    @nexprs 4 k -> (total_libs_k = zero(T))
    # we have to loop through the whole board once
    @inbounds for I in eachindex(board.state)
        cur_flag = board.state[I]
        # if the current position is unoccpuied (flag<1) we say it
        # has no liberties. We have to do this since the stored
        # value for unoccupied spaces is in general nonsense
        cur_libs = ifelse(cur_flag < 1, zero(T), board.liberties[I])
        # increment counter for the group that the current position
        # belongs to. other counters are incremented by 0 as no-op.
        # Note: If some or multiple `flag_k` are 0 (i.e. not a group)
        #       then this works out anyway.
        @nexprs 4 k -> (total_libs_k += ifelse(cur_flag == flag_k, cur_libs, zero(T)))
    end
    @ntuple 4 total_libs
end

function replacegroups!(board::Board{<:AbstractArray{T}}, flags::NTuple{4,T}, new_flag::T) where T
    # unpack group flags (some flags may be 0, indicating empty space)
    @nexprs 4 k -> (flag_k = flags[k])
    # we have to loop through the whole board once
    @inbounds for I in eachindex(board.state)
        cur_flag = board.state[I]
        # check if the current position belongs to any of the 4 groups
        # Note: This will also yield `true` for empty positions if any
        #       of the flags is 0. We handle this issue later
        @nexprs 4 k -> (replace_k = (cur_flag == flag_k))
        cur_isreplace = any(@ntuple(4, replace))
        # if the current position is not occupied (<1) we leave it
        # as is. If it is occupied we check if it is flagged for
        # replacement and if so replace it
        board.state[I] =
            ifelse(cur_flag < one(T), cur_flag,
                   ifelse(cur_isreplace, new_flag, cur_flag))
    end
    board
end

function deletegroups!(board::Board{<:AbstractArray{T}}, flags::NTuple{4,T}, liberties::NTuple{4,T}) where T
    # unpack group flags (some flags may be 0, indicating empty space)
    @nexprs 4 k -> (flag_k = flags[k])
    # compute if group flag is actually a group and if its dead
    @nexprs 4 k -> (isdeadgroup_k = (flag_k > 0) & (liberties[k] < 1))
    # we have to loop through the whole board once
    h, w = size(board)
    @inbounds for j in 1:w, i in 1:h
        cur_flag = board.state[i,j]
        # check if there is a reason to reset current position
        # both of the following conditions must be true for this
        # 1. if current position is part of any group  flag_k (k ∈ 1:4)
        # 2. the group is marked for death (no more liberties)
        @nexprs 4 k -> (reset_k = isdeadgroup_k & (cur_flag==flag_k))
        cur_isreset = any(@ntuple(4, reset))
        board.state[i,j] = ifelse(cur_isreset, zero(T), cur_flag)
        # increase neighbors liberties by 1 if position was reseted
        # otherwise add 0 to it. This avoids braching
        delta_liberty = T(cur_isreset)
        board.liberties[ifelse(i==h,h,i+1), j] += delta_liberty
        board.liberties[ifelse(i==1,1,i-1), j] += delta_liberty
        board.liberties[i, ifelse(j==1,1,j-1)] += delta_liberty
        board.liberties[i, ifelse(j==w,w,j+1)] += delta_liberty
        # note that unoccupied places will have senseless liberties.
        # that is completely fine. they are reseted on placement.
    end
    board
end

function placestone(board::Board{<:AbstractArray{T}}, p1::Type{Val{P1}}, i, j) where {T, P1}
    isturn(board, p1) || error("Currently not player $(P1 ? 1 : 2) turn")
    islegal(board, board.ruleset, p1, i, j) || error("illegal move at ($i, $j)")
    h, w = size(board)
    ZERO = zero(T)
    # see how many friendly and enemy stones are adjacent
    # 1=>up, 2=>down, 3=>left, 4=>right
    friend_1, enemy_1 = getgroup(board, p1, i+1, j)
    friend_2, enemy_2 = getgroup(board, p1, i-1, j)
    friend_3, enemy_3 = getgroup(board, p1, i, j-1)
    friend_4, enemy_4 = getgroup(board, p1, i, j+1)
    num_enemies = 4 - isnull(enemy_1)  - isnull(enemy_2)  - isnull(enemy_3)  - isnull(enemy_4)
    num_friends = 4 - isnull(friend_1) - isnull(friend_2) - isnull(friend_3) - isnull(friend_4)
    # compute the number of liberties at current position
    # note that the `ifelse` statements here are to handle
    # the edges and corners of the board
    num_liberties = ifelse(i==1,0,ifelse(i==h,0,1)) + ifelse(j==1,0,ifelse(j==w,0,1)) + 2 - num_friends - num_enemies
    # check legality at this point

    # TODO: islegal should probably be here

    # now that we know the move is legal lets consider friendly groups
    # NOTE: we introduce a branching here because replacing existing
    #       groups is expensive (because it needs a full pass through
    #       the state array)
    if num_friends == 0
        # no friendly stone around: create new group
        flag = zero(T)
        if P1 # <branch optimized out>
            flag = T(board.player1_grps)
            board.player1_grps += 2
        else
            flag = T(board.player2_grps)
            board.player2_grps += 2
        end
        @inbounds board.state[i,j] = flag
        @inbounds board.liberties[i,j] = num_liberties
    elseif num_friends == 1
        # only one friendly stone around: join its group
        flag = sum(@ntuple 4 k -> get(friend_k, zero(T)))
        @inbounds board.state[i,j] = flag
        @inbounds board.liberties[i,j] = num_liberties
    else
        # multiple friendly stones around: create new group and absorb all
        new_flag = zero(T)
        if P1 # <branch optimized out>
            new_flag = T(board.player1_grps)
            board.player1_grps += 2
        else
            new_flag = T(board.player2_grps)
            board.player2_grps += 2
        end
        old_flags = @ntuple 4 k -> get(friend_k, zero(T))
        replacegroups!(board, old_flags, new_flag)
        @inbounds board.state[i,j] = new_flag
        @inbounds board.liberties[i,j] = num_liberties
        # liberties of friends are updated later
    end
    # we placed the stone and created/merged groups
    # next update surrounding liberties if anyone is adjacent
    if num_liberties < 4 # TODO: maybe remove branch
        decreaseliberties!(board, i-1, j)
        decreaseliberties!(board, i+1, j)
        decreaseliberties!(board, i, j-1)
        decreaseliberties!(board, i, j+1)
    end
    # if an enemy is around, check if it should be captured
    # NOTE: this is expensive and thus condition gated
    if num_enemies > 0
        enemy_flags = @ntuple 4 k -> get(enemy_k, zero(T))
        # compute sum of liberties for surrounding enemy groups
        enemy_libs = groupliberties(board, enemy_flags)
        # remove groups that have no liberty left (i.e. are now captured)
        deletegroups!(board, enemy_flags, enemy_libs)
    end
    # set next player and increase turn counter
    board.numpass = 0
    board.isplayer1 = P1 ? false : true
    board.turn += 1
    board
end

