using Stochy
import Stochy: @cps, cps, desugar, striplineinfo, support, Empirical,
               recoversamples
using Base.Test

dist = @pp enum() do
    local a = flip(0.5),
          b = flip(0.5),
          c = flip(0.5)
    a + b + c
end

@test dist.map == {0=>0.125,1=>0.375,2=>0.375,3=>0.125}

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

hist = [0=>2, 1=>3, 2=>5]
erp = Empirical(hist)
@test erp.n == 10
@test all([x in support(erp) for x in 0:2])
@test length(support(erp)) == 3
for x in 0:2
    @test_approx_eq log(hist[x]*.1) score(erp,x)
end

@test all([sample(erp) in 0:2 for _ in 1:5])

samples = recoversamples(erp)
@test length(samples) == 10
for (x,c) in hist
    @test sum(samples .== x) == c
end


# Hellinger distance.
p = Categorical([0=>0.25,1=>0.25,2=>0.5])
q = Empirical([0=>2,2=>3])
@test_approx_eq_eps 0.36885 hellingerdistance(p,q) 1e-5
@test_throws ErrorException hellingerdistance(q,q)
q = Empirical([3=>1]) # Different support to p.
@test_throws ErrorException hellingerdistance(p,q)


# Categorical.
c = Categorical([0.4,0.6])
@test sample(c) in 1:2
@test score(c,1) == log(0.4)
@test score(c,2) == log(0.6)
@test support(c) == 1:2

c = Categorical([0.4,0.6], [:a,:b])
@test sample(c) in [:a,:b]
@test score(c,:a) == log(0.4)
@test score(c,:b) == log(0.6)
@test support(c) == [:a,:b]

# Dirichlet.
d = Dirichlet(1.,2)
s = sample(d)
@test length(s) == 2
@test sum(s) == 1

# Normal.
n = Normal(0,1)
s = sample(n)
@test 0 < exp(score(n,s)) < 1

# Beta.
b = Beta(1,1)
@test 0 <= sample(b) <= 1
@test score(b,0.5) == 1.0

# CPS

x = 0
cpsid(k,x) = k(x)

id(x) = x

# Atomic Expressions
@test (@cps 0) == 0
@test (@cps x) == x
@test (@cps true) == true
@test (@cps "test") == "test"
@test (@cps :test) == :test
@test eval(cps(:(:test), identity)) == :test
@test (@cps (()->false)()) == false
@test (@cps (x->x)(false)) == false
@test (@cps ((x,y)->x+y)(1, 2)) == 3

# Function calls
@test (@cps cpsid(0)) == 0
@test (@cps ((a...)->a)(1,2)) == (1,2)

# Primatives
@test (@cps 1+1) == 2
@test (@cps x+1) == 1

# Conditionals
@test (@cps if true 1 else 0 end) == 1
@test (@cps if false 1 else 0 end) == 0

# Blocks
@test (@cps begin 1 end) == 1
@test (@cps begin 0; 1 end) == 1

# Function definitions
let
    @cps function f(); false; end
    @test (@cps f()) == :false
end

let
    @cps function f(x) x end
    @test (@cps f(false)) == false
end

let
    @cps function f(x,y) x+y end
    @test (@cps f(1, 2)) == 3
end

# Comparisons
@test (@cps 1==1) == true
@test (@cps x==x) == true
@test (@cps 2>1) == true
@test (@cps 1<2) == true
@test (@cps 1>=1) == true
@test (@cps 1<=1) == true

# Boolean operators
@test (@cps false || false) == false
@test (@cps true || false) == true
@test (@cps false || true) == true
@test (@cps true || true) == true
@test (@cps false && false) == false
@test (@cps true && false) == false
@test (@cps false && true) == false
@test (@cps true && true) == true

# Array literals
@test (@cps [x,1,2]) == [x,1,2]
@test (@cps [x,[1,[2]]]) == [x,1,2]

# Array indexing
@test (@cps [true,false][1]) == true

# Locals
@test (@cps begin; local a=1; a+1 end) == 2
@test (@cps begin; local a=1; local b=2; a+b end) == 3
@test (@cps begin; local a=cpsid(1); a; end) == 1
@test (@cps begin; local a=begin; 1; end; a; end) == 1

# Dot syntax
module M cpsid(k,x) = k(x) end
getmod(k) = k(M)
@test (@cps M.cpsid) == M.cpsid
@test (@cps M.cpsid(0)) == 0
@test (@cps getmod().cpsid(1)) == 1

let
    @cps function fact(n)
        n == 0 ? 1 : n * fact(n - 1)
    end
    @test (@cps fact(5)) == 120
end

# Desugar
expr_eq(e,f) = striplineinfo(e) == striplineinfo(f)

for expr in [:(1),
             :(x),
             :(:test),
             :(function f() false end),
             :(()->false),
             :(begin; end),
             :(f(x)),
             :(begin; f(x, y + z); end)]
    @test desugar(expr) == expr
end

@test expr_eq(desugar(:(begin; local a=1, b=2 end)),
                      :(begin; local a=1; local b=2 end))

@test expr_eq(desugar(:(begin; local a=1,b=2; begin; local x=1, y=2; end; end)),
                      :(begin; local a=1; local b=2; begin; local x=1; local y=2; end; end))

@test expr_eq(desugar(:(function f(); local x=1, y=2 end)),
                      :(function f(); local x=1; local y=2 end))

@test expr_eq(desugar(:(local x=1, y=2)),
                      :(begin; local x=1; local y=2 end)) 

@test expr_eq(desugar(:(~nothing)), :(sample(nothing)))

println("Passed!")
