function Base.show(io::IO, ::MIME"text/plain", board::AbstractBoard)
    h, w = size(board)
    cr_wood = Crayon(background=180, foreground=240)
    cr_reset = Crayon(reset=true)
    cr_black = Crayon(foreground=233)
    cr_white = Crayon(foreground=255)
    println(io, cr_reset, "$h×$w ", typeof(board), ':')
    state = convert(Array, board)
    for i in h:-1:1
        istr = lpad(i,3)
        for j in 1:w
            jstr = lpad(i,2)
            flag = state[i,j]
            j == 1 && print(io, cr_reset, istr, " ", cr_wood, " ")
            if flag < 0
                # these are special flags like "ko"
            elseif flag > 0
                if isplayer1(flag)
                    print(io, cr_wood*cr_black, Int(flag))
                    #print(io, cr_wood*cr_black, "⚈")
                    j < w && print(io, cr_wood, "─")
                    #print(io, cr_wood*cr_black, "⚫")
                    #j < w && print(io, cr_wood, " ")
                else
                    print(io, cr_wood*cr_white, Int(flag))
                    #print(io, cr_wood*cr_white, "◉")
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
                print(io, cr_wood, " ", cr_reset)
                if i == h
                    println(io, cr_reset, " turn: ", board.turn)
                elseif i == h-1
                    println(io, cr_reset, " next: ", board.isplayer1 ? "black" : "white")
                else
                    println(io, cr_reset)
                end
            end
        end
    end
    print(io, cr_reset, " "^5)
    chars = 'A':'Z'
    for j in 1:w
        tj = j < 9 ? j : j+1 # the letter I is skipped ...
        print(io, cr_reset, rpad(chars[tj],2))
    end
end
