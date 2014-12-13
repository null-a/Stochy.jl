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

# Hellinger distance.
@test hellingerdistance(Bernoulli(0.5), Bernoulli(0.5)) == 0
@test hellingerdistance(Bernoulli(1.0), Bernoulli(0.0)) == 1
# Test the case where some values in the support of the exact
# distribution have not been sampled.
p = Appl.Discrete([0=>0.25,1=>0.25,2=>0.5])
q = Appl.Discrete([0=>0.4,2=>0.6], true)
@test hellingerdistance(p,p) == 0
@test 0 < hellingerdistance(p,q) < 1

# Random number generation.

# Gamma.
for (shape,scale) in [(1.,1.),(2.,2.),(0.5,1.)]
    s = Float64[Appl.randgamma(shape,scale) for _ in 1:100_000]
    m = mean(s)
    @test_approx_eq_eps(m, shape*scale, 1e-1)
    @test_approx_eq_eps(varm(s,m), shape*scale^2, 1e-1)
end

# Dirichlet.
for alpha in {[1.,1.],[.5,.5]}
    n = 100_000
    s = Array(Float64, length(alpha), n)
    for i in 1:n
        s[:,i] = Appl.randdirichlet(alpha)
    end
    alpha0 = sum(alpha)
    m = alpha / alpha0
    v = (alpha .* (alpha0-alpha)) / (alpha0^2 * (alpha0+1))
    @test_approx_eq_eps(m, mean(s,2), 1e-2)
    @test_approx_eq_eps(v, var(s,2), 1e-2)
end

# Categorical.
c = Categorical([0.4,0.6])
@test sample(c) in 1:2
@test score(c,1) == log(0.4)
@test score(c,2) == log(0.6)
@test Appl.support(c) == 1:2

c = Categorical([0.4,0.6], [:a,:b])
@test sample(c) in [:a,:b]
@test score(c,:a) == log(0.4)
@test score(c,:b) == log(0.6)
@test Appl.support(c) == [:a,:b]

println("Passed!")
