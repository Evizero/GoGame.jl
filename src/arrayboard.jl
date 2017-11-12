const GRP1_IDX, GRP2_IDX, TURN_IDX, PASS_IDX, PLAYER_IDX = 1, 2, 3, 4, 5

# --------------------------------------------------------------------

struct ArrayBoard{R,A<:AA,L<:AA,S<:AA} <: Board{R}
    ruleset::R
    flags::A
    liberties::L
    state::S # [group_black, group_white, turn, numpass, nextplayer]
end

function ArrayBoard(size::Int = 19, ruleset = ChineseRuleset())
    size ∈ (9, 13, 17, 19) || error("Illegal board size $size")
    flags = zeros(Int, size, size)
    libs  = zeros(Int, size, size)
    state = MVector(1, 2, 1, 0, 1)
    ArrayBoard(ruleset, flags, libs, state)
end

# --------------------------------------------------------------------

Base.summary(board::ArrayBoard{R}) where {R} = string(join(size(board),'×'), ' ', typeof(board).name, '{', R, ",…}")
Base.convert(::Type{Array}, board::ArrayBoard) = Array(board.flags)
@inline Base.size(board::ArrayBoard) = size(board.flags)

@propagate_inbounds isempty(board::ArrayBoard,i,j) =
    iszero(board.flags[i,j])

@propagate_inbounds isko(board::ArrayBoard,i,j) =
    signbit(board.flags[i,j])

@inline function turn(board::ArrayBoard)
    @inbounds res = Int(board.state[TURN_IDX])
    res
end

@inline function nextplayer(board::ArrayBoard)
    @inbounds res = Int(board.state[PLAYER_IDX])
    res
end

# --------------------------------------------------------------------
# main methods for advancing the game

# unsafe because we assume move is by current player
function unsafe_pass!(board::ArrayBoard{R,<:AA{TF},<:AA{TL},<:AA{TS}}) where {R, TF, TL, TS}
    state = board.state
    # update state variables (turn counter, next player, etc)
    @inbounds state[PLAYER_IDX] = TS(ifelse(isplayer1, 2, 1))
    @inbounds state[PASS_IDX] += TS(1)
    @inbounds state[TURN_IDX] += TS(1)
    board
end

# unsafe because we assume move is by current player, legal, and inbounds
function unsafe_placestone!(board::ArrayBoard{R,<:AA{TF},<:AA{TL},<:AA{TS}}, i, j) where {R, TF, TL, TS}
    flags = board.flags
    liberties = board.liberties
    state = board.state
    h, w = size(flags)
    # check who is playing
    player = nextplayer(board)
    isplayer1 = player == 1
    # see how many friendly and enemy stones are adjacent
    # 1=>up, 2=>down, 3=>left, 4=>right
    friend_1, enemy_1 = getgroup(flags, isplayer1, i+1, j)
    friend_2, enemy_2 = getgroup(flags, isplayer1, i-1, j)
    friend_3, enemy_3 = getgroup(flags, isplayer1, i, j-1)
    friend_4, enemy_4 = getgroup(flags, isplayer1, i, j+1)
    num_enemies = 4 - Int(isnull(enemy_1))  - Int(isnull(enemy_2))  - Int(isnull(enemy_3))  - Int(isnull(enemy_4))
    num_friends = 4 - Int(isnull(friend_1)) - Int(isnull(friend_2)) - Int(isnull(friend_3)) - Int(isnull(friend_4))
    # compute the number of liberties at current position
    # note that the `ifelse` statements exist to handle
    # inbounds for the edges and corners of the board
    num_liberties = ifelse(i==1,0,ifelse(i==h,0,1)) + ifelse(j==1,0,ifelse(j==w,0,1)) + 2 - num_friends - num_enemies
    # first lets see if there are friendly groups around
    # NOTE: we introduce a branching here because replacing existing
    #       groups is expensive (because it needs a full pass through
    #       the flags array)
    if num_friends == 0
        # no friendly stone around: create new group
        next_group = TF(ifelse(isplayer1, state[GRP1_IDX], state[GRP2_IDX]))
        @inbounds state[GRP1_IDX] += ifelse(isplayer1, TS(2), TS(0))
        @inbounds state[GRP2_IDX] += ifelse(isplayer1, TS(0), TS(2))
        @inbounds flags[i, j] = next_group
        @inbounds liberties[i, j] = num_liberties
    elseif num_friends == 1
        # only one friendly stone around: join its group
        group = _sum(@ntuple 4 k -> get(friend_k, zero(TF)))
        @inbounds flags[i, j] = group
        @inbounds liberties[i, j] = num_liberties
    else
        # multiple friendly stones around: create new group and absorb all
        next_group = TF(ifelse(isplayer1, state[GRP1_IDX], state[GRP2_IDX]))
        @inbounds state[GRP1_IDX] += ifelse(isplayer1, TS(2), TS(0))
        @inbounds state[GRP2_IDX] += ifelse(isplayer1, TS(0), TS(2))
        old_groups = @ntuple 4 k -> get(friend_k, zero(TF))
        replacegroups!(flags, old_groups, next_group)
        @inbounds flags[i, j] = next_group
        @inbounds liberties[i, j] = num_liberties
        # (note: liberties of friends are updated later)
    end
    # we placed the stone and created/merged groups
    # next we update surrounding liberties (if anyone is adjacent)
    if num_liberties < 4 # TODO: maybe remove branch
        decreaseliberties!(flags, liberties, i-1, j)
        decreaseliberties!(flags, liberties, i+1, j)
        decreaseliberties!(flags, liberties, i, j-1)
        decreaseliberties!(flags, liberties, i, j+1)
    end
    # if an enemy is around, check if it should be captured
    # NOTE: this is expensive and thus condition gated
    if num_enemies > 0
        enemy_groups = @ntuple 4 k -> get(enemy_k, zero(TF))
        # compute sum of liberties for surrounding enemy groups
        enemy_libs = countliberties(flags, liberties, enemy_groups)
        # remove groups that have no liberty left (i.e. are now captured)
        deletegroups!(flags, liberties, enemy_groups, enemy_libs)
    end
    # update state variables (turn counter, next player, etc)
    @inbounds state[PLAYER_IDX] = TS(ifelse(isplayer1, 2, 1))
    @inbounds state[PASS_IDX] = TS(0)
    @inbounds state[TURN_IDX] += TS(1)
    board
end

# --------------------------------------------------------------------
# helper functions

function countliberties(flags::AA{T}, liberties::AA{R}, groups::NTuple{4,T}) where {T,R}
    # unpack groups (some groups may be 0, indicating empty positions)
    @nexprs 4 k -> (group_k = groups[k])
    # initialize total-liberties counter for each (potential) group
    @nexprs 4 k -> (total_libs_k = zero(R))
    # we have to loop through the whole board once
    @inbounds for I in eachindex(flags)
        cur_flag = flags[I]
        # if the current position is unoccupied (flag<1) we say it
        # has no liberties. We have to do this since the stored
        # value for unoccupied spaces is in general nonsense
        cur_libs = ifelse(cur_flag < one(T), zero(R), liberties[I])
        # increment counter for the group that the current position
        # belongs to. Other counters are incremented by 0 as no-op.
        # Note: If some or multiple `group_k` are 0 (i.e. not a group)
        #       then this works out anyway.
        @nexprs 4 k -> (total_libs_k += ifelse(cur_flag == group_k, cur_libs, zero(R)))
    end
    # return the total liberties for each of the 4 groups
    @ntuple 4 k -> total_libs_k
end

function decreaseliberties!(flags::AA{T}, liberties::AA{R}, i::Integer, j::Integer) where {T,R}
    h, w = size(flags)
    # clamp the indices to legal range to avoid branches
    # this is just so that we don't get bounds issues
    # we later simply ignore the clamped cases
    ti = clamp(i, one(i), h)
    tj = clamp(j, one(j), w)
    @inbounds flag = flags[ti, tj]
    @inbounds libs = liberties[ti, tj]
    # ignore any empty positions as well as clamped indices
    ignore = (flag < one(T)) | (ti != i) | (tj != j)
    # decrease liberties unless position is ignored
    @inbounds liberties[ti, tj] = ifelse(ignore, libs, libs - one(R))
    nothing
end

function getgroup(flags::AA{T}, isplayer1::Bool, i::Integer, j::Integer) where {T}
    h, w = size(flags)
    # clamp the indices to legal range to avoid branches
    # this is just so that we don't get bounds issues
    # we later simply ignore the clamped cases
    ti = clamp(i, one(i), h)
    tj = clamp(j, one(j), w)
    @inbounds flag = flags[ti, tj]
    # ignore any empty positions as well as clamped indices
    ignore = (flag < one(T)) | (ti != i) | (tj != j)
    # check if the flag is a group of the current player
    correct_player = ifelse(isplayer1, isodd(Int(flag)), iseven(Int(flag)))
    # if the current position is empty we return two Null
    # otherwise we return the flag as either friend or enemy,
    # depending on which player is making the current move
    ifelse(ignore,(Nullable{T}(), Nullable{T}()),
           ifelse(correct_player,
                  (Nullable{T}(flag), Nullable{T}()),
                  (Nullable{T}(),     Nullable{T}(flag))))
end

function replacegroups!(flags::AA{T}, groups::NTuple{4,T}, new_group::T) where T
    # unpack groups (some groups may be 0, indicating empty positions)
    @nexprs 4 k -> (group_k = groups[k])
    # we have to loop through the whole flags once
    @inbounds for I in eachindex(flags)
        cur_flag = flags[I]
        # check if the current position belongs to any of the 4 groups
        # Note: This will also yield `true` for empty positions if any
        #       of the groups is 0. We handle this issue below
        @nexprs 4 k -> (replace_k = (cur_flag == group_k))
        cur_isreplace = _any(@ntuple(4, k -> replace_k))
        # if the current position is not occupied (flag<1) we leave
        # it as is. If it is occupied we check if it is flagged for
        # replacement and if so replace it
        flags[I] = ifelse(cur_flag < one(T), cur_flag,
                          ifelse(cur_isreplace, new_group, cur_flag))
    end
    nothing
end

function deletegroups!(flags::AA{T}, liberties::AA{R}, groups::NTuple{4,T}, libs::NTuple{4,R}) where {T,R}
    h, w = size(flags)
    # unpack groups (some groups may be 0, indicating empty positions)
    @nexprs 4 k -> (group_k = groups[k])
    # compute if group is actually a group and if its dead
    @nexprs 4 k -> (isdeadgroup_k = (group_k > zero(T)) & (libs[k] < one(R)))
    # we have to loop through the whole board once
    @inbounds for j in 1:w, i in 1:h
        cur_flag = flags[i,j]
        # check if there is a reason to reset current position.
        # both of the following conditions must be true for this
        # 1. the current position is part of some given group (k ∈ 1:4)
        # 2. the group is marked for death (no more liberties)
        @nexprs 4 k -> (reset_k = isdeadgroup_k & (cur_flag==group_k))
        cur_isreset = _any(@ntuple(4, k -> reset_k))
        flags[i,j] = ifelse(cur_isreset, zero(T), cur_flag)
        # increase neighbors liberties by 1 if position was reset
        # otherwise add 0 to it as no-op. This avoids branching.
        delta_liberty = T(cur_isreset)
        # note that unoccupied places will have senseless liberties.
        # if at the edge of the board it will add liberties to itself
        # both is completely fine. these values are reset on placement.
        liberties[ifelse(i==h,h,i+1), j] += delta_liberty
        liberties[ifelse(i==1,1,i-1), j] += delta_liberty
        liberties[i, ifelse(j==1,1,j-1)] += delta_liberty
        liberties[i, ifelse(j==w,w,j+1)] += delta_liberty
    end
    nothing
end
