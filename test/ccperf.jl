using Stochy

println("@cps")
fact = @cps n -> n==0 ? 1 : n * fact(n-1)
@time [@cps fact(20) for _ in 1:10_000];

println("@cps_cc")


fact = @cps_cc n -> n==0 ? 1 : n * fact(n-1)

#factexpr = cc(Stochy.cps(:(n -> n==0 ? 1 : n * fact(n-1)), :identity))
#Meta.show_sexpr(factexpr)
#fact = nothing
#fact = eval(factexpr)
#println(fact)
#fact.env = (==,*,-,Stochy,fact)
#println(fact)


@time [@cps_cc fact(20) for _ in 1:10_000];

#@profile [@cps_cc fact(20) for _ in 1:1_000];
#Profile.print()
