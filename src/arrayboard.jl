const GRP1_IDX, GRP2_IDX, TURN_IDX, PASS_IDX, PLAYER_IDX, KO_IDX = 1, 2, 3, 4, 5, 6

# --------------------------------------------------------------------

struct ArrayBoard{R,A<:AA,L<:AA,S<:AA} <: Board{R}
    ruleset::R
    flags::A
    liberties::L
    state::S # [group_black, group_white, turn, numpass, nextplayer, ko]
end

function ArrayBoard(size::Int = 19, ruleset = ChineseRuleset())
    size ∈ (9, 13, 17, 19) || error("Illegal board size $size")
    flags = zeros(Int, size, size)
    libs  = zeros(Int, size, size)
    state = MVector(1, 2, 1, 0, 1, 0)
    ArrayBoard(ruleset, flags, libs, state)
end

# --------------------------------------------------------------------
# public info methods

Base.summary(board::ArrayBoard{R}) where {R} = string(join(size(board),'×'), ' ', typeof(board).name, '{', R, ",…}")
Base.convert(::Type{Array}, board::ArrayBoard) = Array(board.flags)
@inline Base.size(board::ArrayBoard) = size(board.flags)

@propagate_inbounds isempty(board::ArrayBoard,i,j) =
    iszero(board.flags[i,j])

@inline function isko(board::ArrayBoard{R,<:AA{TF},<:AA{TL},<:AA{TS}},i,j) where {R, TF, TL, TS}
    @inbounds ko_idx = Int(board.state[KO_IDX])
    sub2ind(size(board), i, j) == ko_idx
end

@inline function turn(board::ArrayBoard)
    @inbounds res = Int(board.state[TURN_IDX])
    res
end

@inline function nextplayer(board::ArrayBoard)
    @inbounds res = Int(board.state[PLAYER_IDX])
    res
end

@inline function isgameover(board::ArrayBoard{R,<:AA{TF},<:AA{TL},<:AA{TS}}) where {R, TF, TL, TS}
    @inbounds res = board.state[PASS_IDX] >= TS(2)
    res
end

function issuicide(board::ArrayBoard{R,<:AA{TF},<:AA{TL},<:AA{TS}}, player, i, j) where {R, TF, TL, TS}
    flags = board.flags
    liberties = board.liberties
    state = board.state
    h, w = size(board)
    @boundscheck (1 <= i <= h) && (1 <= j <= w)
    # check who is playing (we assume its the given player's turn)
    isplayer1 = player == 1
    # see how many friendly and enemy stones are adjacent
    # 1=up, 2=down, 3=left, 4=right
    friend_1, enemy_1 = getgroup(flags, isplayer1, i+1, j)
    friend_2, enemy_2 = getgroup(flags, isplayer1, i-1, j)
    friend_3, enemy_3 = getgroup(flags, isplayer1, i, j-1)
    friend_4, enemy_4 = getgroup(flags, isplayer1, i, j+1)
    # sum up how many friends and enemies are around
    num_enemies = 4 - Int(iszero(enemy_1))  - Int(iszero(enemy_2))  - Int(iszero(enemy_3))  - Int(iszero(enemy_4))
    num_friends = 4 - Int(iszero(friend_1)) - Int(iszero(friend_2)) - Int(iszero(friend_3)) - Int(iszero(friend_4))
    # compute the number of liberties at current position
    # note that the `ifelse` statements exist to handle
    # inbounds for the edges and corners of the board
    max_liberties = ifelse(i==1,0,ifelse(i==h,0,1)) + ifelse(j==1,0,ifelse(j==w,0,1)) + 2
    num_liberties = max_liberties - num_friends - num_enemies
    # if any liberty, don't even bother checking further
    if num_liberties > 0
        # this is surely the much more common branch
        return false
    else
        # we have to be sneaky and cheat here!
        # in order to not double count group liberties we have
        # to temporarily decrease the neighbours liberties.
        # this simulates us placing the stones
        addliberties!(flags, liberties, i-1, j, TL(-1))
        addliberties!(flags, liberties, i+1, j, TL(-1))
        addliberties!(flags, liberties, i, j-1, TL(-1))
        addliberties!(flags, liberties, i, j+1, TL(-1))
        # compute sum of liberties for surrounding groups
        enemy_libs  = countliberties(flags, liberties, @ntuple(4, enemy))
        friend_libs = countliberties(flags, liberties, @ntuple(4, friend))
        # compute if group is actually a group and if it would die
        @nexprs 4 k -> (isdeadenemy_k = (enemy_k > zero(TF)) & (enemy_libs[k] < TL(1)))
        @nexprs 4 k -> (isdeadfriend_k = (friend_k > zero(TF)) & (friend_libs[k] < TL(1)))
        # check if there would be any capture or self capture
        anycapture = _any(@ntuple(4, isdeadenemy))
        anyselfcapture = _sum(@ntuple(4, isdeadfriend)) >= num_friends
        # now lets add back those temporary liberties
        addliberties!(flags, liberties, i-1, j, one(TL))
        addliberties!(flags, liberties, i+1, j, one(TL))
        addliberties!(flags, liberties, i, j-1, one(TL))
        addliberties!(flags, liberties, i, j+1, one(TL))
        # if any enemy gets captured then it's not considered suicide
        # if no enemy gets captured then there must be at least
        # one friendly group that wouldn't self capture
        ifelse(anycapture, false, ifelse(num_friends>0, anyselfcapture, true))
    end
end

# --------------------------------------------------------------------
# main methods for advancing the game

# we assume move is by current player and game is not over
function unsafe_pass!(board::ArrayBoard{R,<:AA{TF},<:AA{TL},<:AA{TS}}) where {R, TF, TL, TS}
    state = board.state
    # update state variables (turn counter, next player, etc)
    @inbounds state[PLAYER_IDX] = ifelse(isplayer1, TS(2), TS(1))
    @inbounds state[PASS_IDX] += TS(1)
    @inbounds state[TURN_IDX] += TS(1)
    board
end

# we assume move is by current player, legal, and inbounds
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
    friends = @ntuple 4 k -> friend_k
    enemies = @ntuple 4 k -> enemy_k
    # sum up how many friends and enemies are around
    num_enemies = 4 - Int(iszero(enemy_1))  - Int(iszero(enemy_2))  - Int(iszero(enemy_3))  - Int(iszero(enemy_4))
    num_friends = 4 - Int(iszero(friend_1)) - Int(iszero(friend_2)) - Int(iszero(friend_3)) - Int(iszero(friend_4))
    # compute the number of liberties at current position
    # note that the `ifelse` statements exist to handle
    # inbounds for the edges and corners of the board
    max_liberties = ifelse(i==1,0,ifelse(i==h,0,1)) + ifelse(j==1,0,ifelse(j==w,0,1)) + 2
    num_liberties = max_liberties - num_friends - num_enemies
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
        @inbounds flags[i, j] = _sum(friends)
        @inbounds liberties[i, j] = num_liberties
    else
        # multiple friendly stones around: create new group and absorb all
        next_group = TF(ifelse(isplayer1, state[GRP1_IDX], state[GRP2_IDX]))
        @inbounds state[GRP1_IDX] += ifelse(isplayer1, TS(2), TS(0))
        @inbounds state[GRP2_IDX] += ifelse(isplayer1, TS(0), TS(2))
        replacegroups!(flags, friends, next_group)
        @inbounds flags[i, j] = next_group
        @inbounds liberties[i, j] = num_liberties
        # (note: liberties of friends are updated later)
    end
    # we placed the stone and created/merged groups
    # next we update surrounding liberties (if anyone is adjacent)
    if num_liberties < 4 # TODO: maybe remove condition to remove branch
        addliberties!(flags, liberties, i+1, j, TL(-1))
        addliberties!(flags, liberties, i-1, j, TL(-1))
        addliberties!(flags, liberties, i, j-1, TL(-1))
        addliberties!(flags, liberties, i, j+1, TL(-1))
    end
    # reset ko since we may or may not overwrite it
    @inbounds state[KO_IDX] = TS(0)
    # if an enemy is around, check if it should be captured
    # NOTE: this is expensive and thus condition gated
    if num_enemies > 0
        # compute sum of liberties for surrounding enemy groups
        enemy_libs = countliberties(flags, liberties, enemies)
        # remove groups that have no liberty left (i.e. are now captured)
        num_del = deletegroups!(flags, liberties, enemies, enemy_libs)
        # check if only one stone was removed (potential ko)
        is1 = _sum(num_del) == 1
        koidx = ifelse(is1 & (num_del[1]==1), sub2ind((h,w),i+1,j), 0)
        koidx = ifelse(is1 & (num_del[2]==1), sub2ind((h,w),i-1,j), koidx)
        koidx = ifelse(is1 & (num_del[3]==1), sub2ind((h,w),i,j-1), koidx)
        koidx = ifelse(is1 & (num_del[4]==1), sub2ind((h,w),i,j+1), koidx)
        # if also initially surrounded my enemies then its a ko
        @inbounds state[KO_IDX] = ifelse(max_liberties == num_enemies, TS(koidx), TS(0))
    end
    # update state variables (turn counter, next player, etc)
    @inbounds state[PLAYER_IDX] = ifelse(isplayer1, TS(2), TS(1))
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

function addliberties!(flags::AA{T}, liberties::AA{R}, i::Integer, j::Integer, delta) where {T,R}
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
    @inbounds liberties[ti, tj] = ifelse(ignore, libs, libs + R(delta))
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
    ifelse(ignore, (zero(T), zero(T)),
           ifelse(correct_player, (flag, zero(T)), (zero(T), flag)))
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
    # initialize total-delete counter for each (potential) group
    @nexprs 4 k -> (total_delete_k = 0)
    # we have to loop through the whole board once
    @inbounds for j in 1:w, i in 1:h
        cur_flag = flags[i,j]
        # check if there is a reason to reset current position.
        # both of the following conditions must be true for this
        # 1. the current position is part of some given group (k ∈ 1:4)
        # 2. the group is marked for death (no more liberties)
        @nexprs 4 k -> (reset_k = isdeadgroup_k & (cur_flag==group_k))
        @nexprs 4 k -> (total_delete_k += ifelse(reset_k, 1, 0))
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
    # return the total number of removed stones for each of the 4 groups
    @ntuple 4 k -> total_delete_k
end
