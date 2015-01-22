import Stochy: pass_store

@test pass_store(:(function f(); end), :x) == :(function f(x); end)
@test pass_store(:(function f(y); end), :x) == :(function f(x,y); end)
@test pass_store(:(function f(y,z); end), :x) == :(function f(x,y,z); end)

@test pass_store(:(f()), :x) == :(f(x))
@test pass_store(:(f(y)), :x) == :(f(x,y))
@test pass_store(:(f(y,z)), :x) == :(f(x,y,z))

@test expr_eq(pass_store(:(()->false), :x), :((x,)->false))
@test expr_eq(pass_store(:((y)->false), :x), :((x,y)->false))
@test expr_eq(pass_store(:((y,z)->false), :x), :((x,y,z)->false))

@test expr_eq(pass_store(:(f(g())), :x), :(f(x,g(x))))

@test expr_eq(pass_store(:(f()()), :x), :(f(x)(x)))

# Don't pass store to primitives, thunk constructor or trampoline.
@assert :+ in Stochy.primitives
@test expr_eq(pass_store(:(1+2), :x), :(1+2))

expr = :(Stochy.trampoline(Stochy.Thunk(()->false)))
@test expr_eq(pass_store(expr, :x), expr)

# Other syntax.
expr = quote
    if x > 0 || y == :test && a.b < 0
        [true,false][1]
    else
        "none"
    end
end

@test expr_eq(pass_store(expr, :x), expr)
