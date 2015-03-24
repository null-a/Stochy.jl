using Stochy

# This is useful for testing inference over models where the number of
# ERP varies across executions.

@pp function f(n)
    factor(n > 3 ? -1 : 0)
    if n < 0
        list()
    else
        flip(0.7) ? 0 .. f(n-1) : list()
    end
end

@pp function g()
    f(5)
end

dist = @pp enum() do
    local x = g()
    x
end

println(dist)
println("\n\n")

dist = @pp mh(1000) do
    local x = g()
    x
end

println(dist)
println("\n\n")
