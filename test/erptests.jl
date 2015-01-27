# Discrete.
hist = [0=>2, 1=>3, 2=>5]
erp = Discrete(hist)
@test all([x in support(erp) for x in 0:2])
@test length(support(erp)) == 3
for x in 0:2
    @test_approx_eq(log(hist[x]/10),score(erp,x))
end

@test all([rand(erp) in 0:2 for _ in 1:5])

# Hellinger distance.
p = Categorical([0.25,0.25,0.5])
q = Discrete([1=>2, 3=>3])
@test_approx_eq_eps 0.36885 hellingerdistance(p,q) 1e-5
q = Discrete([4=>1]) # Different support to p.
@test_throws ErrorException hellingerdistance(p,q)
