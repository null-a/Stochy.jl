import Stochy: free, substitute, cc

@test free(:(x+y)) == Set([:x,:y,:+])
@test free(:(x->x+y)) == Set([:y,:+])
@test free(:(x->y->x+y)) == Set([:+])

@test substitute([:y=>:z], :(x+y)) == :(x+z)

# Dot syntax.

expr = quote
    f -> begin
        x -> begin
            f().identity(x)
        end
    end
end

newexpr = cc(expr)
@test call(call(eval(newexpr), ()->Base), :x) == :x

# Matt Might's test case.

expr = quote
    f -> begin
        b -> begin
            c -> begin
                f(a,b,c)
            end
        end
    end
end

a = :a
newexpr = cc(expr)
#println(newexpr)
result = call(call(call(eval(newexpr), (args...)->args), :b), :c)
#println(result)
@test result == (:a,:b,:c)

# Argument shadowing global.

expr = quote
    () -> begin
        a
        a -> begin
            a
        end
    end
end

a = :global
newexpr = cc(expr)
#println(newexpr)
result = call(call(eval(newexpr)), :arg)
#println(result)
@test result == :arg # rather than :global

# Recursive function.

factexpr = cc(:(n -> n==0 ? 1 : n*fact(n-1)))
println(factexpr)
fact = eval(factexpr)
@test eval(cc(:(fact(5)))) == 120

# CPS code.

cpsfactexpr = cps(:(n -> n==0 ? 1 : n*fact(n-1)), :identity)
println(striplineinfo(cpsfactexpr))
println(striplineinfo(cc(cpsfactexpr)))

fact = eval(cc(cpsfactexpr))
println(eval(cc(cps(:(fact(20)), :identity))))
