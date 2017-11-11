using PkgBenchmark
using GoGame

@benchgroup "placestone" begin
    @bench "9"  placestone(b, Val{true}, 3, 3) setup=(b=Board(9))  evals=1
    @bench "19" placestone(b, Val{true}, 3, 3) setup=(b=Board(19)) evals=1
end

@benchgroup "sequence" begin
    function f(board)
        placestone(board, Val{true}, 1, 1)
        placestone(board, Val{false}, 2, 1)
        placestone(board, Val{true}, 1, 2)
        placestone(board, Val{false}, 2, 2)
        placestone(board, Val{true}, 5, 5)
        placestone(board, Val{false}, 1, 3)
    end
    @bench "9"  f(b) setup=(b=Board(9))  evals=1
    @bench "19" f(b) setup=(b=Board(19)) evals=1
end

nothing
