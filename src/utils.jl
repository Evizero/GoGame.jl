const AA{T,N} = AbstractArray{T,N}

@inline _any(tup::NTuple{4}) = tup[1]|tup[2]|tup[3]|tup[4]
@inline _sum(tup::NTuple{4}) = tup[1]+tup[2]+tup[3]+tup[4]
