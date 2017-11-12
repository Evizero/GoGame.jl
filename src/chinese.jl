struct ChineseRuleset <: Ruleset end

function islegal(board::Board{ChineseRuleset}, player, i, j)
    h, w = size(board)
    @boundscheck (1 <= i <= h) && (1 <= j <= w)
    # check if the desired position is unoccupied
    @inbounds allow = isempty(board, i, j)::Bool
    # if the spot is marked as "ko" it can not be played
    @inbounds allow = ifelse(isko(board, i, j), false, allow)
    # TODO: if any liberty, don't even bother checking further
    # TODO: check if neighbour group can get captured
    # TODO: check if suicide
    allow
end
