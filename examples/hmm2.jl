# This is the HMM from the particle filter chapter (ch5).

using Appl, DataStructures

@appl function hmm(states, observations)
    if observations == list()
        reverse(states)
    else
        local prevstate = first(states),
              state = flip(prevstate ? 0.9 : 0.1)
        factor(state == first(observations) ? 0 : -1)
        hmm(state..states, tail(observations))
    end
end

dist = @appl enum() do
    hmm(list(false), list(true,true,true,true))
end

println("Exact:\n", dist)

dist = @appl smc(100) do
    hmm(list(false), list(true,true,true,true))
end

println("SMC:\n", dist)
