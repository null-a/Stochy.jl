using Stochy
#Stochy.debug(true)

# This is a hack used to ensure that all the first particle has all of
# the probability mass at the first factor statement. Therefore, after
# resampling, all particles are descendants of the same particle. When
# the store isn't correctly handled the memo cache ends up been shared
# resulting in incorrect results.

c = 0
function count(store,k)
    global c
    c += 1
    k(store,c)
end

# This should return a uniform distribution over true/false.

dist = @pp pmcmc(1,100) do
    local f = mem(_->flip())
    factor(count() == 1 ? 0 : -Inf)
    f(0)
end

println(dist)
