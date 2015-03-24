export addressing, @addressing

macro addressing(expr)
    expr |> addressing |> esc
end

function addressing(expr::Expr)
    wrapfunc = isfuncdef(expr) ? identity : awrap
    expr |> at |> wrapfunc
end

const addressarg = symbol("##address")

awrap(expr) = :(($addressarg -> $expr)(list(0)))

function at(expr::Expr)
    if expr.head == :function
        @assert length(expr.args) == 2
        @assert expr.args[1].head == :call
        name = expr.args[1].args[1]
        args = expr.args[1].args[2:end]
        body = expr.args[2]
        :(function $name($addressarg, $(args...)); $(at(body)); end)
    elseif expr.head == :->
        args = procargs(expr.args[1])
        body = expr.args[2]
        :(($addressarg, $(args...)) -> $(at(body)))
    elseif expr.head == :call && expr.args[1] in primitives
        Expr(:call, expr.args[1], map(at, expr.args[2:end])...)
    elseif expr.head == :call
        func = at(expr.args[1]) # Recurse for e.g. dot syntax.
        args = expr.args[2:end]
        rest = map(at, args)
        id = genaddr()
        :($(func)(cons($id, $addressarg), $(rest...)))
    elseif expr.head == :local
        @assert expr.args[1].head == symbol("=")
        @assert length(expr.args[1].args) == 2
        var = expr.args[1].args[1]
        val = expr.args[1].args[2]
        :(local $var = $(at(val)))
    elseif expr.head in [:comparison, :block, :if, :&&, :||, :vcat, :ref, :., :...]
        expr.head == :comparion && (@assert expr.args[2] in compops)
        Expr(expr.head, map(at, expr.args)...)
    elseif expr.head in [:line, :quote]
        expr
    else
        error("unhandled $(expr.head) expression in addressing transform")
    end
end

at(expr::Symbol) = expr
at(expr::LineNumberNode) = expr
at(expr::Number) = expr # Bool subclasses number apparantly.
at(expr::QuoteNode) = expr
at(expr::String) = expr

block(exprs...) = Expr(:block, exprs...)

# I don't really like this, but threading a counter through at() seems
# tedious. I think I have to maintain some state anyway, in order to
# ensure that addresses are unique across all @pp blocks.

_addr = 0

function genaddr()
    global _addr
    _addr += 1
end

function resetaddressingcounter()
    global _addr
    _addr = 0
end
