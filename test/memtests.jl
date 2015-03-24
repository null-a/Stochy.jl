@pp function model()
    local g = mem(_->flip(0.7))
    flip(0.6)
    g(0)
end

for algo in [enum, enumdepthfirst, enumlikelyfirst]
    dist = @pp algo(model)
    @test_approx_eq(exp(score(dist, true)), 0.7)
    @test_approx_eq(exp(score(dist, false)), 0.3)
end

comps = [
() -> begin
    @pp pmcmc(1,100) do
        local f = mem(_->flip())
        f(0)
    end
end,
() -> begin
    @pp begin
        local f = mem(_->flip())
        pmcmc(1,100) do
            f(0)
        end
    end
end,
() -> begin
    f = @pp mem(_->flip())
    @pp pmcmc(1,100) do
        f(0)
    end
end]

for comp in comps
    supp = support(comp())
    @test length(supp) == 2
    @test true in supp
    @test false in supp
end

# This is a hack used to ensure that all the first particle has all of
# the probability mass at the first factor statement. Therefore, after
# resampling, all particles are descendants of the same particle. When
# the store isn't correctly handled the memo cache ends up been shared
# resulting in incorrect results.

# I think this made more sense when continuations were copied during
# resampling. I'm not sure how this could fail now, but it's worth
# keeping around.

c = 0
function count(store,k,address)
    global c
    c += 1
    k(store,c)
end

dist = @pp pmcmc(1,100) do
    local f = mem(_->flip())
    factor(count() == 1 ? 0 : -Inf)
    f(0)
end
supp = support(dist)

@test length(supp) == 2
@test true in supp
@test false in supp
