# Tests based on: http://okmij.org/ftp/Scheme/delim-cont.scm

result = @pp 10 + reset(() -> 2 + shift(k -> 100 + k(k(3))))
@test result == 117

result = @pp 10 * reset(() -> 2 * shift(g -> 5 * shift(f -> f(1) + 1)))
@test result == 60

result = @pp begin
    local f = x -> shift(k -> k(k(x)))
    1 + reset(() -> 10 + f(100))
end
@test result == 121

result = @pp begin
    reset() do
        local x = shift(f -> shift(f1 -> f1(cons(:a, f(list())))))
        shift(g -> x)
    end
end
@test result == list(:a)

@pp function visit(xs)
    if xs == list()
        list()
    else
        visit(shift(k -> cons(first(xs), k(tail(xs)))))
    end
end

@pp function traverse(xs)
    reset(() -> visit(xs))
end

result = @pp traverse(list(1,2,3,4,5))
@test result == list(1,2,3,4,5)
