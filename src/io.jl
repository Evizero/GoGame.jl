function printletters(io::IO, board)
    cr_reset = Crayon(reset=true)
    print(io, cr_reset, " "^5)
    chars = 'A':'Z'
    for j in 1:size(board)[2]
        tj = j < 9 ? j : j+1 # the letter I is skipped ...
        print(io, cr_reset, rpad(chars[tj],2))
    end
    nothing
end

function Base.show(io::IO, ::MIME"text/plain", board::Board{R}) where R
    h, w = size(board)
    cr_wood = Crayon(background=180, foreground=240)
    cr_reset = Crayon(reset=true)
    cr_black = Crayon(foreground=233)
    cr_white = Crayon(foreground=255)
    println(io, cr_reset, summary(board), ':')
    printletters(io, board)
    println(io, cr_reset, " "^6,  "┌──── STATE ────┐")
    flags = convert(Array, board)
    for i in h:-1:1
        istr = lpad(i,3)
        for j in 1:w
            jstr = lpad(i,2)
            flag = flags[i,j]
            j == 1 && print(io, cr_reset, istr, " ", cr_wood, " ")
            if isko(board, i, j)
                print(io, cr_wood, "⦻")
                j < w && print(io, cr_wood, "─")
            elseif flag > 0
                if isodd(Int(flag)) # isplayer1
                    #print(io, cr_wood*cr_black, Int(flag))
                    print(io, cr_wood*cr_black, "⚈")
                    j < w && print(io, cr_wood, "─")
                    #print(io, cr_wood*cr_black, "⚫")
                    #j < w && print(io, cr_wood, " ")
                else
                    #print(io, cr_wood*cr_white, Int(flag))
                    print(io, cr_wood*cr_white, "◉")
                    #print(io, cr_wood*cr_white, "⚉")
                    j < w && print(io, cr_wood, "─")
                    #print(io, cr_wood*cr_white, "⚪")
                    #j < w && print(io, cr_wood, " ")
                end
            elseif i == h && j == 1
                print(io, cr_wood, "┌─")
            elseif i == h && j == w
                print(io, cr_wood, "┐")
            elseif i == 1 && j == 1
                print(io, cr_wood, "└─")
            elseif i == 1 && j == w
                print(io, cr_wood, "┘")
            elseif i == h
                print(io, cr_wood, "┬─")
            elseif i == 1
                print(io, cr_wood, "┴─")
            elseif j == 1
                print(io, cr_wood, "├─")
            elseif j == w
                print(io, cr_wood, "┤")
            else
                print(io, cr_wood, "┼─")
            end
            if j == w
                print(io, cr_wood, " ", cr_reset, " ", rpad(i,2))
                if i == h
                    println(io, cr_reset, "   │ Turn: ", rpad(turn(board),8), "│")
                elseif i == h-1
                    println(io, cr_reset, "   │ Next: ", rpad(nextplayer(board)==1 ? "black" : "white",8), "│")
                elseif i == h-2
                    println(io, cr_reset, "   └───────────────┘")
                else
                    println(io, cr_reset)
                end
            end
        end
    end
    printletters(io, board)
end
