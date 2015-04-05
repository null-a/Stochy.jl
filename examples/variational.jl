using Stochy

@pp function f()
    local x = flip()
    local y = flip()
    local z = flip()
    factor(x||y ? 0 : -1)
    x+y+z
end

p = @pp enum(f)
println("Exact:")
println(p)

q = @pp enum(variational(f, 10, 10000))
println("Variational approximation:")
println(q)

k = kl(p,q)
println("KL divergence: $k")

# Exact:
# 2 | 0.445384113713482
# 1 | 0.3515386287621726
# 3 | 0.14846137123782735
# 0 | 0.05461588628651796
# INFO: Variational inference converged after 4841 steps.
# Variational approximation:
# 2 | 0.4146164710210265
# 1 | 0.32919181385372215
# 3 | 0.17045227764404255
# 0 | 0.08573943748120881
# KL divergence: 0.009832540321298086
