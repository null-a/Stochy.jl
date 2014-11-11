using Appl
using DataStructures

@appl function transition(state)
    state==1 ? flip(0.7) : flip(0.3)
end

@appl function observe(state)
    state==1 ? flip(0.9) : flip(0.1)
end

@appl function hmm(n)
    if n == 0
        local states       = list(1),
              observations = list()
        list(states, observations)
    else
        local prev       = hmm(n-1),
              prevstates = first(prev),
              prevobs    = second(prev),
              newstate   = transition(first(prevstates)),
              newobs     = observe(newstate)
        list(newstate..prevstates, newobs..prevobs)
    end
end

dist = @appl enum() do
    local trueobs = list(0,0,0),
          r = hmm(3)
    factor(trueobs == second(r) ? 0 : -Inf)
    tail(reverse(first(r)))
end

println(dist)
