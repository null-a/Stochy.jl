export DP

# Stick breaking construction.

@pp function pickstick(sticks, j)
    flip(sticks(j)) ? j : pickstick(sticks, j+1)
end

@pp function makesticks(alpha)
    local sticks = mem(index -> ~Beta(1.0, alpha))
    () -> pickstick(sticks,1)
end

@pp function DP(thunk, alpha)
    local atoms = mem(index -> thunk())
    local sticks = makesticks(alpha)
    () -> atoms(sticks())
end
