using GoGame
using Base.Test
using ReferenceTests

@testset "simple sequence" begin
    board = ArrayBoard(9)
    @test all(board.flags .== 0)
    placestone(board, 1, 1, 1)
    @test board.flags[1,1] == 1
    @test board.liberties[1,1] == 2
    placestone(board, 2, 2, 1)
    @test board.flags[2,1] == -1
    @test board.liberties[1,1] == 1
    @test board.liberties[2,1] == 2
    placestone(board, 1, 1, 2)
    @test board.flags[1,2] == 1
    @test board.liberties[1,1] == 0
    @test board.liberties[2,1] == 2
    @test board.liberties[1,2] == 2
    placestone(board, 2, 2, 2)
    @test board.flags[2,2] == -1
    @test board.liberties[1,1] == 0
    @test board.liberties[2,1] == 1
    @test board.liberties[1,2] == 1
    @test board.liberties[2,2] == 2
    placestone(board, 1, 5, 5)
    @test board.flags[5,5] == 2
    @test board.liberties[5,5] == 4
    placestone(board, 2, 1, 3)
    @test board.flags[1,3] == -2
    @test board.flags[1,1] == 0
    @test board.flags[1,2] == 0
    @test board.liberties[2,1] == 2
    @test board.liberties[2,2] == 3
    @test board.liberties[1,3] == 3
    placestone(board, 1, 5, 6)
    @test board.flags[5,6] == 2
    placestone(board, 2, 1, 2)
    @test board.flags[2,1] == -3
    @test board.flags[2,2] == -3
    @test board.flags[1,3] == -3
    @test board.flags[1,2] == -3
    @test board.flags[1,1] == 0
    @test board.liberties[2,1] == 2
    @test board.liberties[2,2] == 2
    @test board.liberties[1,2] == 1
    @test board.liberties[1,3] == 2
end
