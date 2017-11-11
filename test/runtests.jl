using GoGame
using Base.Test
using ReferenceTests

@testset "simple sequence" begin
    board = Board(9)
    @test all(board.state .== 0)
    placestone(board, Val{true}, 1, 1)
    @test board.state[1,1] == 1
    @test board.liberties[1,1] == 2
    placestone(board, Val{false}, 2, 1)
    @test board.state[2,1] == 2
    @test board.liberties[1,1] == 1
    @test board.liberties[2,1] == 2
    placestone(board, Val{true}, 1, 2)
    @test board.state[1,2] == 1
    @test board.liberties[1,1] == 0
    @test board.liberties[2,1] == 2
    @test board.liberties[1,2] == 2
    placestone(board, Val{false}, 2, 2)
    @test board.state[2,2] == 2
    @test board.liberties[1,1] == 0
    @test board.liberties[2,1] == 1
    @test board.liberties[1,2] == 1
    @test board.liberties[2,2] == 2
    placestone(board, Val{true}, 5, 5)
    @test board.state[5,5] == 3
    @test board.liberties[5,5] == 4
    placestone(board, Val{false}, 1, 3)
    @test board.state[1,3] == 4
    @test board.state[1,1] == 0
    @test board.state[1,2] == 0
    @test board.liberties[2,1] == 2
    @test board.liberties[2,2] == 3
    @test board.liberties[1,3] == 3
    placestone(board, Val{true}, 5, 6)
    @test board.state[5,6] == 3
    placestone(board, Val{false}, 1, 2)
    @test board.state[2,1] == 6
    @test board.state[2,2] == 6
    @test board.state[1,3] == 6
    @test board.state[1,2] == 6
    @test board.state[1,1] == 0
    @test board.liberties[2,1] == 2
    @test board.liberties[2,2] == 2
    @test board.liberties[1,2] == 1
    @test board.liberties[1,3] == 2
end
