# Enumeration.

dist = @pp enum() do
    local
    a = flip(0.5),
    b = flip(0.5),
    c = flip(0.5)
    factor(a||b ? 0 : -1)
    a + b + c
end

@test_approx_eq(exp(score(dist,0)), 0.054615886286517)
@test_approx_eq(exp(score(dist,1)), 0.351538628762172)
@test_approx_eq(exp(score(dist,2)), 0.445384113713482)
@test_approx_eq(exp(score(dist,3)), 0.148461371237827)

@test_throws ErrorException @pp enum() do
    factor(-Inf)
    true
end

# Ensure the context is restored when an exception occurs during
# enumeration.
try @pp enum(()->foo())
catch e
    if isa(e, UndefVarError)
        @test Stochy.ctx == Stochy.Prior()
    else
        rethrow(e)
    end
end


# PMCMC.

dist = @pp pmcmc(5,5) do
    local x = flip()
    factor(x ? 0 : -1)
    x
end

@test length(support(dist)) == 2
@test true in support(dist)
@test false in support(dist)

try @pp pmcmc(()->foo(),1,1)
catch e
    if isa(e, UndefVarError)
        @test Stochy.ctx == Stochy.Prior()
    else
        rethrow(e)
    end
end


# MH.

dist = @pp mh(5) do
    local x = flip(0.5)
    factor(x ? 0 : -1)
    x
end

@test issubset(support(dist), [true, false])

try @pp mh(()->foo(),1)
catch e
    if isa(e, UndefVarError)
        @test Stochy.ctx == Stochy.Prior()
    else
        rethrow(e)
    end
end
