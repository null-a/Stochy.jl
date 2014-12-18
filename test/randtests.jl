using Stochy
using Base.Test

# Random number generation.

# Gamma.
for (shape,scale) in [(1.,1.),(2.,2.),(0.5,1.)]
    s = Float64[Stochy.randgamma(shape,scale) for _ in 1:100_000]
    m = mean(s)
    @test_approx_eq_eps(m, shape*scale, 1e-1)
    @test_approx_eq_eps(varm(s,m), shape*scale^2, 1e-1)
end

# Dirichlet.
for alpha in {[1.,1.],[.5,.5]}
    n = 100_000
    s = Array(Float64, length(alpha), n)
    for i in 1:n
        s[:,i] = Stochy.randdirichlet(alpha)
    end
    alpha0 = sum(alpha)
    m = alpha / alpha0
    v = (alpha .* (alpha0-alpha)) / (alpha0^2 * (alpha0+1))
    @test_approx_eq_eps(m, mean(s,2), 1e-2)
    @test_approx_eq_eps(v, var(s,2), 1e-2)
end

println("Passed!")
