import Stochy: cps, desugar, striplineinfo

x = 0
cpsid(k,x) = k(x)

id(x) = x

# Atomic Expressions
@test (@cps 0) == 0
@test (@cps x) == x
@test (@cps true) == true
@test (@cps "test") == "test"
@test (@cps :test) == :test
@test eval(cps(:(:test), :identity)) == :test
@test (@cps (()->false)()) == false
@test (@cps (x->x)(false)) == false
@test (@cps ((x,y)->x+y)(1, 2)) == 3

# Function calls
@test (@cps cpsid(0)) == 0
@test (@cps ((a...)->a)(1,2)) == (1,2)

# Primitives
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

# Ellipsis
@test (@cps tuple([1,2]...)) == (1,2)

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
