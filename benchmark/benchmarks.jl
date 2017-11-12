using PkgBenchmark
using GoGame

@benchgroup "placestone" begin
    @bench "9"  placestone(b, 1, 3, 3) setup=(b=ArrayBoard(9))  evals=1
    @bench "19" placestone(b, 1, 3, 3) setup=(b=ArrayBoard(19)) evals=1
end

@benchgroup "sequence" begin
    function f(board)
        placestone(board, 1, 1, 1)
        placestone(board, 2, 2, 1)
        placestone(board, 1, 1, 2)
        placestone(board, 2, 2, 2)
        placestone(board, 1, 5, 5)
        placestone(board, 2, 1, 3)
    end
    @bench "9"  f(b) setup=(b=ArrayBoard(9))  evals=1
    @bench "19" f(b) setup=(b=ArrayBoard(19)) evals=1
end

nothing
