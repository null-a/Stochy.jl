using Stochy
#Stochy.debug(true)

# It seems to me as though the following should all be equivalent,
# returning an approximately uniform distribution over true/false.

# This always works as each execution of the computation passed to
# pmcmc creates a new cache for the memoized function.

dist = @pp begin
    pmcmc(1,100) do
        local f = mem(_->flip())
        f(0)
    end
end
println(dist)

dist = @pp begin
    local f = mem(_->flip())
    pmcmc(1,100) do
        f(0)
    end
end
println(dist)

# When I first started playing with non-parametrics I was defining
# memoized function in their own @pp blocks, much as I've done
# elsewhere. It doesn't seem reasonable to expect people to reason
# about @pp blocks having these kinds of effects.

f = @pp mem(_->flip())
dist = @pp begin
    pmcmc(1,100) do
        f(0)
    end
end
println(dist)
