abstract type Board{R<:Ruleset} end

"""
    isempty(board, i::Int, j::Int) -> Bool

Return true if the position (i,j) is unoccupied.
"""
function isempty end

"""
    isko(board, i::Int, j::Int) -> Bool

Return true if the position (i,j) is flagged as "ko".
"""
function isko end

"""
    isturn(board, player::Int) -> Bool

Return true if it is `player`'s turn to make a move.
"""
isturn(board, player) = (player == nextplayer(board))

"""
    pass(board, player::Int)

Advance game without placing a stone. This passes the control
to the other player.
"""
function pass(board::Board, player::Int)
    isturn(board, player) || error("Currently not player $player turn")
    unsafe_pass!(board)
    # TODO: check two player pass in a row ?
    board
end

"""
    placestone(board, player::Int, i::Int, j::Int)

Place a stone for `player` at `(i,j)` (if it is the `player`'s turn
and it is a legal move), and pass control to the other player.
"""
function placestone(board::Board, player::Int, i, j)
    h, w = size(board)
    isturn(board, player) || error("Currently not player $player turn")
    islegal(board, player, i, j) || error("illegal move at ($i, $j)")

    unsafe_placestone!(board, i, j)
    # TODO: check if game is over?
    board
end
