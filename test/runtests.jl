using Appl
using Base.Test

dist = @appl enum() do
    local a = flip(0.5),
          b = flip(0.5),
          c = flip(0.5)
    a + b + c
end

println(dist)
@test dist.hist == {0=>0.125,1=>0.375,2=>0.375,3=>0.125}

# Ensure the context is restored when an exception occurs during
# enumeration.
try @appl enum(()->foo())
catch e
    if isa(e, UndefVarError)
        @test Appl.ctx == Appl.Prior()
    else
        rethrow(e)
    end
end

hist = [0=>0.2, 1=>0.3, 2=>0.5]
erp = Appl.Discrete(hist)
@test all([x in Appl.support(erp) for x in 0:2])
@test all([Appl.score(erp, x) == log(hist[x]) for x in 0:2])

println("Passed!")
