function countliberties(state::AbstractArray{T}, liberties::AbstractArray{T}, groups::NTuple{4,T}) where T
    # unpack group groups (some groups may be 0, indicating empty space)
    @nexprs 4 k -> (group_k = groups[k])
    # initialize total-liberties counter for each (potential) group
    @nexprs 4 k -> (total_libs_k = zero(T))
    # we have to loop through the whole board once
    @inbounds for I in eachindex(state)
        cur_flag = state[I]
        # if the current position is unoccpuied (flag<1) we say it
        # has no liberties. We have to do this since the stored
        # value for unoccupied spaces is in general nonsense
        cur_libs = ifelse(cur_flag < one(T), zero(T), liberties[I])
        # increment counter for the group that the current position
        # belongs to. other counters are incremented by 0 as no-op.
        # Note: If some or multiple `group_k` are 0 (i.e. not a group)
        #       then this works out anyway.
        @nexprs 4 k -> (total_libs_k += ifelse(cur_flag == group_k, cur_libs, zero(T)))
    end
    @ntuple 4 k -> total_libs_k
end

function decreaseliberties!(state::AbstractArray{T}, liberties::AbstractArray{T}, i::Integer, j::Integer) where T
    h, w = size(state)
    # clamp the indices to legal range to avoid branches
    # this is just so that we don't get boundserror
    # we later simply ignore the clamped cases
    ti = clamp(i, one(i), h)
    tj = clamp(j, one(j), w)
    @inbounds flag = state[ti, tj]
    @inbounds libs = liberties[ti, tj]
    # ignore any empty positions as well as clamped indices
    ignore = (flag < one(T)) | (ti != i) | (tj != j)
    # decrease liberties unless position is ignored
    @inbounds liberties[ti, tj] = ifelse(ignore, libs, libs - one(T))
    nothing
end

function getgroup(state::AbstractArray{T}, ::Type{Val{P1}}, i::Integer, j::Integer) where {T, P1}
    h, w = size(state)
    # clamp the indices to legal range to avoid branches
    # this is just so that we don't get boundserror
    # we later simply ignore the clamped cases
    ti = clamp(i, one(i), h)
    tj = clamp(j, one(j), w)
    @inbounds flag = state[ti, tj]
    # ignore any empty positions as well as clamped indices
    ignore = (flag < one(T)) | (ti != i) | (tj != j)
    # check if the flag is a group of the current player
    # <branch optimized out>
    correct_player = P1 ? isplayer1(flag) : isplayer2(flag)
    # if the current position is empty we return two null
    # otherwise we return the flag as friend or enemy,
    # depending on which player we are
    ifelse(ignore,(Nullable{T}(), Nullable{T}()),
           ifelse(correct_player,
                  (Nullable{T}(flag), Nullable{T}()),
                  (Nullable{T}(),     Nullable{T}(flag))))
end

function replacegroups!(state::AbstractArray{T}, groups::NTuple{4,T}, new_group::T) where T
    # unpack group groups (some groups may be 0, indicating empty space)
    @nexprs 4 k -> (group_k = groups[k])
    # we have to loop through the whole state once
    @inbounds for I in eachindex(state)
        cur_flag = state[I]
        # check if the current position belongs to any of the 4 groups
        # Note: This will also yield `true` for empty positions if any
        #       of the groups is 0. We handle this issue below
        @nexprs 4 k -> (replace_k = (cur_flag == group_k))
        cur_isreplace = any(@ntuple(4, k -> replace_k))
        # if the current position is not occupied (<1) we leave it
        # as is. If it is occupied we check if it is flagged for
        # replacement and if so replace it
        state[I] = ifelse(cur_flag < one(T), cur_flag,
                          ifelse(cur_isreplace, new_group, cur_flag))
    end
    state
end

function deletegroups!(state::AbstractArray{T}, liberties::AbstractArray{T}, groups::NTuple{4,T}, libs::NTuple{4,T}) where T
    h, w = size(state)
    # unpack groups (some groups may be 0, indicating empty space)
    @nexprs 4 k -> (group_k = groups[k])
    # compute if group is actually a group and if its dead
    @nexprs 4 k -> (isdeadgroup_k = (group_k > 0) & (libs[k] < 1))
    # we have to loop through the whole board once
    @inbounds for j in 1:w, i in 1:h
        cur_flag = state[i,j]
        # check if there is a reason to reset current position
        # both of the following conditions must be true for this
        # 1. if current position is part of any group (k ∈ 1:4)
        # 2. the group is marked for death (no more liberties)
        @nexprs 4 k -> (reset_k = isdeadgroup_k & (cur_flag==group_k))
        cur_isreset = any(@ntuple(4, k -> reset_k))
        state[i,j] = ifelse(cur_isreset, zero(T), cur_flag)
        # increase neighbors liberties by 1 if position was reseted
        # otherwise add 0 to it. This avoids braching
        delta_liberty = T(cur_isreset)
        liberties[ifelse(i==h,h,i+1), j] += delta_liberty
        liberties[ifelse(i==1,1,i-1), j] += delta_liberty
        liberties[i, ifelse(j==1,1,j-1)] += delta_liberty
        liberties[i, ifelse(j==w,w,j+1)] += delta_liberty
        # note that unoccupied places will have senseless liberties.
        # that is completely fine. they are reseted on placement.
    end
    nothing
end

# unsafe because we assume move is legal and inbounds
function unsafe_placestone!(state::AbstractArray{T}, liberties::AbstractArray{T}, group_counter::C, p1::Type{Val{P1}}, i, j) where {T, C, P1}
    h, w = size(state)
    # see how many friendly and enemy stones are adjacent
    # 1=>up, 2=>down, 3=>left, 4=>right
    friend_1, enemy_1 = getgroup(state, p1, i+1, j)
    friend_2, enemy_2 = getgroup(state, p1, i-1, j)
    friend_3, enemy_3 = getgroup(state, p1, i, j-1)
    friend_4, enemy_4 = getgroup(state, p1, i, j+1)
    num_enemies = 4 - Int(isnull(enemy_1))  - Int(isnull(enemy_2))  - Int(isnull(enemy_3))  - Int(isnull(enemy_4))
    num_friends = 4 - Int(isnull(friend_1)) - Int(isnull(friend_2)) - Int(isnull(friend_3)) - Int(isnull(friend_4))
    # compute the number of liberties at current position
    # note that the `ifelse` statements exist to handle
    # the edges and corners of the board
    num_liberties = ifelse(i==1,0,ifelse(i==h,0,1)) + ifelse(j==1,0,ifelse(j==w,0,1)) + 2 - num_friends - num_enemies
    # now that we know the move is legal lets consider friendly groups
    # NOTE: we introduce a branching here because replacing existing
    #       groups is expensive (because it needs a full pass through
    #       the state array)
    if num_friends == 0
        # no friendly stone around: create new group
        group = T(group_counter)
        group_counter += C(2)
        @inbounds state[i, j] = group
        @inbounds liberties[i, j] = num_liberties
    elseif num_friends == 1
        # only one friendly stone around: join its group
        group = sum(@ntuple 4 k -> get(friend_k, zero(T)))
        @inbounds state[i, j] = group
        @inbounds liberties[i, j] = num_liberties
    else
        # multiple friendly stones around: create new group and absorb all
        new_group = T(group_counter)
        group_counter += C(2)
        old_groups = @ntuple 4 k -> get(friend_k, zero(T))
        replacegroups!(state, old_groups, new_group)
        @inbounds state[i, j] = new_group
        @inbounds liberties[i, j] = num_liberties
        # liberties of friends are updated later
    end
    # we placed the stone and created/merged groups
    # next we update surrounding liberties (if anyone is adjacent)
    if num_liberties < 4 # TODO: maybe remove branch
        decreaseliberties!(state, liberties, i-1, j)
        decreaseliberties!(state, liberties, i+1, j)
        decreaseliberties!(state, liberties, i, j-1)
        decreaseliberties!(state, liberties, i, j+1)
    end
    # if an enemy is around, check if it should be captured
    # NOTE: this is expensive and thus condition gated
    if num_enemies > 0
        enemy_groups = @ntuple 4 k -> get(enemy_k, zero(T))
        # compute sum of liberties for surrounding enemy groups
        enemy_libs = countliberties(state, liberties, enemy_groups)
        # remove groups that have no liberty left (i.e. are now captured)
        deletegroups!(state, liberties, enemy_groups, enemy_libs)
    end
    group_counter
end
