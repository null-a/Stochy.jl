typealias Store Dict{Any,Any}

function storetransform(expr::Expr)
    storearg = symbol("##store")
    emptystoreexpr = :(Stochy.Store())
    Expr(:block, Expr(symbol("="), storearg, emptystoreexpr), pass_store(expr, storearg))
end

function store_exit(store, value)
    debug() && println("store@exit: $store")
    value
end

function pass_store(expr::Expr, arg::Symbol)
    p(expr) = pass_store(expr, arg)
    if expr.head == :function
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        func = expr.args[1].args[1]
        args = expr.args[1].args[2:end]
        body = expr.args[2]
        Expr(:function, Expr(:call, func, [arg, args]...), p(body))
    elseif expr.head == :->
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        args = isa(expr.args[1], Symbol) ? [expr.args[1]] : expr.args[1].args
        body = expr.args[2]
        Expr(:->, Expr(:tuple, [arg,args]...), p(body))
    elseif expr.head == :call && expr.args[1] == :(Stochy.Thunk)
        @assert expr.args[2].head == :->
        @assert length(expr.args) == 2
        @assert length(expr.args[2].args) == 2
        Expr(:call, expr.args[1], Expr(:->, expr.args[2].args[1], p(expr.args[2].args[2])))
    elseif expr.head == :call && !((expr.args[1] in primitives) || (expr.args[1] == :(Stochy.trampoline)))
        func = expr.args[1]
        args = expr.args[2:end]
        Expr(:call, p(func), [arg, [p(a) for a in args]]...)
    elseif expr.head in [:block,:if,:||,:&&,:comparison,:call,:.,:quote,:vcat,:ref,:...]
        Expr(expr.head, [p(e) for e in expr.args]...)
    elseif expr.head == :line
        expr
    else
        error("unhandled $(expr.head) expression in pass_store")
    end
end

pass_store(expr::LineNumberNode, _) = expr
pass_store(expr::Atom, _) = expr
