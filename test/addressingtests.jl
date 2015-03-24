function testaddr(expr, expectedwithlines)
    Stochy.resetaddressingcounter()
    actual = Stochy.at(expr) |> Stochy.striplineinfo
    expected = expectedwithlines |> Stochy.striplineinfo
    @test actual == expected
    # if actual == expected
    #     println("*")
    # else
    #     println("Failure")
    #     println("Expected:")
    #     println(expected)
    #     println("Got:")
    #     println(actual)
    #     println()
    # end
end

# Values.

testaddr(:(0), :(0))
testaddr(:(x), :(x))
testaddr(:(false), :(false))
testaddr(:(:x), :(:x))
testaddr(Expr(:quote, :x), Expr(:quote, :x))
testaddr(:("foo"), :("foo"))

# Blocks.

testaddr(:(begin; end), :(begin; end))
testaddr(:(begin; x; end), :(begin; x; end))
testaddr(:(begin; x; y; end), :(begin; x; y; end))
testaddr(:(begin; x; begin; y; end; end), :(begin; x; begin; y; end; end))

# Function definitions.
# TODO: Lose these extra blocks.

testaddr(:(function f(); 0; end), :(function f($(Stochy.addressarg)); begin; 0; end; end))
testaddr(:(function f(x); 0; end), :(function f($(Stochy.addressarg), x); begin; 0; end; end))
testaddr(:(function f(x, y); 0; end), :(function f($(Stochy.addressarg), x, y); begin; 0; end; end))

testaddr(:(() -> false), :(($(Stochy.addressarg),) -> begin; false; end))
testaddr(:(x -> false), :(($(Stochy.addressarg), x) -> begin; false; end))
testaddr(:((x) -> false), :(($(Stochy.addressarg), x) -> begin; false; end))
testaddr(:((x,y) -> false), :(($(Stochy.addressarg), x, y) -> begin; false; end))

testaddr(:((args...) -> false), :(($(Stochy.addressarg), args...) -> begin; false; end))
testaddr(:((x, args...) -> false), :(($(Stochy.addressarg), x, args...) -> begin; false; end))

# Function application.
testaddr(:(f()), :(f(cons(1, $(Stochy.addressarg)))))
testaddr(:(f(x)), :(f(cons(1, $(Stochy.addressarg)), x)))

# Compound examples.

testaddr(:(function f(); g(); end), :(function f($(Stochy.addressarg)); begin; g(cons(1, $(Stochy.addressarg))); end; end))
testaddr(:(() -> f()), :(($(Stochy.addressarg),) -> begin; f(cons(1, $(Stochy.addressarg))); end))
testaddr(:(f(g())), :(f(cons(2, $(Stochy.addressarg)), g(cons(1, $(Stochy.addressarg))))))

# Other syntax.
testaddr(:(begin; local x = f(); end), :(begin; local x = f(cons(1, $(Stochy.addressarg))); end))
testaddr(:(f() ? g(0) : g(1)), :(f(cons(1, $(Stochy.addressarg))) ? g(cons(2, $(Stochy.addressarg)), 0) : g(cons(3, $(Stochy.addressarg)), 1)))
testaddr(:(f() && g()), :(f(cons(1, $(Stochy.addressarg))) && g(cons(2, $(Stochy.addressarg)))))
testaddr(:(f() || g()), :(f(cons(1, $(Stochy.addressarg))) || g(cons(2, $(Stochy.addressarg)))))
testaddr(:(f().g()), :(f(cons(1, $(Stochy.addressarg))).g(cons(2, $(Stochy.addressarg)))))
testaddr(:(f() == g()), :(f(cons(1, $(Stochy.addressarg))) == g(cons(2, $(Stochy.addressarg)))))
testaddr(:([f(), g()]), :([f(cons(1, $(Stochy.addressarg))), g(cons(2, $(Stochy.addressarg)))]))
testaddr(:(f()[g()]), :(f(cons(1, $(Stochy.addressarg)))[g(cons(2, $(Stochy.addressarg)))]))
testaddr(:([f()...]), :([f(cons(1,$(Stochy.addressarg)))...]))
