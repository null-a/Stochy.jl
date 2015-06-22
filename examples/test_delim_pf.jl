using Stochy
using DataStructures

dist = @pp pf(1000) do
    local a = flip()
    local b = flip()
    factor(!a ? 0 : -1)
    a + b
end


dist2 = @pp enum() do
    local a = flip()
    local b = flip()
    factor(!a ? 0 : -1)
    a + b
end

println(dist)
println(dist2)
