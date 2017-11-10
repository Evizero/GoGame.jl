module GoGame

export

    Board,
    islegal

mutable struct Board
    state::Matrix{UInt8}
    turn::Int
    player::Bool
end

function Board(size::Int = 19)
    size ∈ (9, 13, 17, 19) || error("Illegal board size $size")
    Board(zeros(UInt8, size, size), 0, 1)
end

function Base.show(io::IO, board::Board)
    h, w = size(board)
    println(io, "$h×$w ", typeof(board).name)
    for i in h:-1:1
        istr = lpad(i,3)
        for j in 1:w
            jstr = lpad(i,2)
            val = board.state[i,j]
            j == 1 && print(io, istr, " ")

            if val == 1
                print(io, "⚪ ")
            elseif val == 2
                print(io, "⚫ ")
            elseif i == h && j == 1
                print(io, "┌─")
            elseif i == h && j == w
                print(io, "┐")
            elseif i == 1 && j == 1
                print(io, "└─")
            elseif i == 1 && j == w
                print(io, "┘")
            elseif i == h
                print(io, "┬─")
            elseif i == 1
                print(io, "┴─")
            elseif j == 1
                print(io, "├─")
            elseif j == w
                print(io, "┤")
            else
                print(io, "┼─")
            end
            j == w && println(io)
        end
    end
    print(io, "    ")
    chars = 'A':'Z'
    for j in 1:w
        tj = j < 9 ? j : j+1 # the letter I is skipped ...
        print(io, rpad(chars[tj],2))
    end
end

@inline Base.size(board::Board) = size(board.state)

@inline isturn(board, player) = player == board.player

function islegal(board::Board, i, j, player)
    @assert player == 1 || player == 2 # make checkbounds
    # checkbounds
    isturn(board, player) || return false
end

function Base.setindex!(board::Board, player, i, j)
    islegal(board, i, j, player) || error("Currently not player $player turn")
    # applymove
    # set new player
end

end # module
