export Closure, call, cc, @cc, @cps_cc

# Closure conversion based on:
# http://matt.might.net/articles/closure-conversion/

cc(expr::Expr) = expr |> transform |> dropglobals |> lift |> translate# |> x->(println(x);x)

macro cc(expr)
    esc(cc(expr))
end

macro cps_cc(expr)
    ret = cc(cps(expr, :identity))
    #println(ret)
    esc(ret)
end

# Helpers.
function fargs(expr::Expr)
    @assert expr.head == :->
    f(e::Symbol) = [e]
    f(e::Expr) = (@assert e.head == :tuple; e.args)
    f(expr.args[1])
end


# Convert individual (not-recursively) anonymous fuctions into
# abstract syntax for creating closures.

function closureconvert(expr::Expr)
    if expr.head == :->
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        envsym = gensym("env")
        # TODO: Is cumbersome later one? Perhaps keep if matches
        # exiting function/lambda layout.
        newargs = Expr(:tuple, envsym, fargs(expr)...)
        fv = free(expr)
        # TODO: Maybe it's this which is tricky/inconvinient later on?
        env = [Expr(:tuple, v, v) for v in fv]
        subs = Dict([(v,Expr(:envref, envsym, v)) for v in fv])
        newbody = substitute(subs, expr.args[2])
        lambdaexpr = Expr(symbol("->*"), newargs, newbody)
        Expr(:makeclosure, lambdaexpr, Expr(:makeenv, env...))
    elseif expr.head == :call
        # TODO: Do I really need to map :call => :applyclosure?
        Expr(:applyclosure, expr.args...)
    elseif expr.head in [:block, :line, :if, symbol("->*"), :makeclosure, :makeenv, :envref, :applyclosure, :comparison,:.]
        # TODO: Make this the else block?
        expr
    else
        error("unrecognized $(expr.head) expression in closureconvert")
    end
end

closureconvert(expr::Symbol) = expr

function free(expr::Expr)
    if expr.head == :->
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        args = fargs(expr)
        body = expr.args[2]
        setdiff(free(body), Set(args))
    elseif expr.head == symbol("->*")
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        # TODO: Extract helper.
        args = isa(expr.args[1], Symbol) ? [expr.args[1]] : expr.args[1].args
        body = expr.args[2]
        vars = setdiff(free(body), Set(args))
        @assert length(vars) == 0
        Set()
    elseif expr.head in [:block, :comparison, :.]
        union(Set(), [free(e) for e in expr.args]...)
    elseif expr.head == :if
        @assert length(expr.args) == 3
        union(Set(), [free(e) for e in expr.args]...)
    elseif expr.head == :line
        Set()
    elseif expr.head == :makeclosure
        union(free(expr.args[1]), free(expr.args[2]))
    elseif expr.head == :makeenv
        union(Set(), [free(e.args[2]) for e in expr.args]...)
    elseif expr.head == :envref
        free(expr.args[1])
    elseif expr.head == :applyclosure
        union(Set(), [free(e) for e in expr.args]...)
    elseif expr.head == :call
        union(Set(), [free(e) for e in expr.args]...)
    else
        error("unrecognized $(expr.head) expression in free")
    end
end

free(expr::QuoteNode) = Set()
free(expr::LineNumberNode) = Set()
free(expr::Symbol) = Set({expr})
free(expr::Union(Bool,Int64)) = Set()



# TODO: I can probably collapse a lot of the cases here.

function substitute(subs, expr::Expr)
    if expr.head == :->
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        #args = extractargs(expr)
        # TODO: Filter out subs which appear in args once I understand
        # how such a situation arises. May be this only happens if
        # working top-down?
        # TODO: extractargs helper.
        args = isa(expr.args[1], Symbol) ? [expr.args[1]] : expr.args[1].args
        for (k,v) in subs
            k in args && error("requested substitution is argument to lambda")
        end
        Expr(:->, expr.args[1], substitute(subs, expr.args[2]))
    elseif expr.head == symbol("->*")
        # TODO: Use helper.
        args = isa(expr.args[1], Symbol) ? [expr.args[1]] : expr.args[1].args
        s = filter((k,v) -> !(k in args), subs)
        Expr(symbol("->*"), expr.args[1], substitute(s, expr.args[2]))
    elseif expr.head in [:block, :comparison, :.]
        Expr(expr.head, [substitute(subs,e) for e in expr.args]...)
    elseif expr.head == :if
        Expr(:if, [substitute(subs,e) for e in expr.args]...)
    elseif expr.head == :makeclosure
        Expr(:makeclosure, substitute(subs, expr.args[1]), substitute(subs, expr.args[2]))
    elseif expr.head == :makeenv
        Expr(:makeenv, [Expr(:tuple, e.args[1], substitute(subs, e.args[2])) for e in expr.args]...)
    elseif expr.head == :envref
        Expr(:envref, substitute(subs, expr.args[1]), expr.args[2])
    elseif expr.head == :applyclosure
        Expr(:applyclosure, [substitute(subs,e) for e in expr.args]...)
    elseif expr.head == :call
        Expr(:call, [substitute(subs,e) for e in expr.args]...)
    elseif expr.head == :line
        expr
    else
        error("unrecognized $(expr.head) expression in substitute")
    end
end

substitute(subs, expr::LineNumberNode) = expr
substitute(subs, expr::QuoteNode) = expr
substitute(subs, expr::Symbol) = get(subs, expr, expr)
substitute(subs, expr::Number) = expr



# Recursively convert closures working bottom-up.


# TODO: Several of these cases can be combined but just mapping over
# expr.args.


function transform(expr::Expr)
    t = transform
    newexpr = if expr.head == :->
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block # Body.
        argsexpr = expr.args[1]
        bodyexpr = expr.args[2]
        Expr(:->, argsexpr, t(bodyexpr))
    elseif expr.head == symbol("->*")
        @assert length(expr.args) == 2
        @assert isa(expr.args[1], Symbol) # TODO: Multiple arguments.
        @assert expr.args[2].head == :block # Body.
        args = expr.args[1]
        body = expr.args[2]
        Expr(symbol("->*"), args, t(body))        
    elseif expr.head == :line
        expr
    elseif expr.head in [:block, :comparison, :.]
        Expr(expr.head, [t(e) for e in expr.args]...)
    elseif expr.head == :if
        Expr(:if, [t(e) for e in expr.args]...)
    elseif expr.head == :makeclosure
        Expr(:makeclosure, t(expr.args[1]), t(expr.args[2]))
    elseif expr.head == :makeenv
        Expr(:makeenv, [Expr(:tuple, e.args[1], t(e.args[2])) for e in expr.args]...)
    elseif expr.head == :envref
        Expr(:envref, t(expr.args[1]), expr.args[2])
    elseif expr.head == :applyclosure
        Expr(:applyclosure, [t(e) for e in expr.args]...)
    elseif expr.head == :call
        Expr(:call, [t(e) for e in expr.args]...)
    else
        error("unrecognized $(expr.head) expression in transform")
    end
    closureconvert(newexpr)
end

transform(expr::LineNumberNode) = expr
transform(expr::Symbol) = expr
transform(expr::Number) = expr
transform(expr::QuoteNode) = expr



# Convert each closure's lambda expression into a top-level generic
# function.

function lift(expr::Expr)
    function iter(expr::Expr)
        if expr.head == :makeclosure
            f = gensym()
            args = expr.args[1].args[1].args
            body = iter(expr.args[1].args[2])
            env = expr.args[2]
            func = :(function $f($(args...)) $body end)
            push!(funcs, func)
            Expr(:makeclosure, f, env)
        else
            Expr(expr.head, [iter(arg) for arg in expr.args]...)
        end
    end
    iter(expr::Symbol) = expr
    iter(expr::Number) = expr
    iter(expr::LineNumberNode) = expr
    iter(expr::QuoteNode) = expr
    funcs = Expr[]
    liftedexpr = iter(expr)
    Expr(:block, [funcs, liftedexpr]...)
end


# Convert abstract syntax into Julia.

immutable Closure
    f::Function
    env::Dict{Symbol,Any}
end

call(c::Closure, args...) = c.f(c.env, args...)
call(f::Union(Function,Type), args...) = f(args...)

function translate(expr::Expr)
    if expr.head == :makeclosure
        f = expr.args[1]::Symbol
        env = translate(expr.args[2])
        :(Closure($f, $env))
    elseif expr.head == :makeenv
        dictexpr = Expr(:dict)
        for e in expr.args
            @assert e.head == :tuple
            push!(dictexpr.args, Expr(symbol("=>"), QuoteNode(e.args[1]), translate(e.args[2])))
        end
        dictexpr
    elseif expr.head == :envref
        env = expr.args[1]
        var = expr.args[2]
        Expr(:ref, env, QuoteNode(var))
    elseif expr.head == :applyclosure
        :(call($([translate(e) for e in expr.args]...)))
    elseif expr.head in [:block,:function,:call,:if,:comparison,:.]
        Expr(expr.head, [translate(e) for e in expr.args]...)
    elseif expr.head == :line
        expr
    else
        error("unrecognized $(expr.head) expression in translate")
    end
end

translate(expr::QuoteNode) = expr
translate(expr::Symbol) = expr
translate(expr::Number) = expr
translate(expr::LineNumberNode) = expr


# Assume that variables added to the outer-most closures are globals.
# These can therefore be removed from the environment and reference
# directly. The primary motivation for this is it makes it possibe to
# define recursive function like so from Julia.
# fact = @cc n -> n==0 ? 1 : n * fact(n-1)


# Find the outer-most closure.

function dropglobals(expr::Expr)
    if expr.head == :makeclosure
        @assert expr.args[1].head == symbol("->*")
        makeenvexpr = expr.args[2]
        @assert makeenvexpr.head == :makeenv
        globals = Symbol[e.args[1] for e in makeenvexpr.args]
        Expr(:makeclosure, dropglobals_inner(expr.args[1], globals), Expr(:makeenv))
    elseif expr.head in [:block,:applyclosure,:.]
        Expr(expr.head, [dropglobals(e) for e in expr.args]...)
    elseif expr.head == :line
        expr
    else
        error("unrecognised $(expr.head) expression in dropglobals")
    end
end

dropglobals(expr::QuoteNode) = expr
dropglobals(expr::Symbol) = expr
dropglobals(expr::Number) = expr


# Recursively update references to globals.

function dropglobals_inner(expr::Expr, globals::Vector{Symbol})
    if expr.head == :envref
        expr.args[2] in globals ? expr.args[2] : expr
    elseif expr.head == :makeenv
        Expr(:makeenv, filter(e->!(e.args[1] in globals), expr.args)...)
    elseif expr.head == symbol("->*")
        args = expr.args[1].args
        g = filter(v->!(v in args), globals)
        Expr(expr.head, [dropglobals_inner(e,g) for e in expr.args]...)
    elseif expr.head in [:tuple,:block,:makeclosure,:applyclosure,:if,:comparison,:.]
        Expr(expr.head, [dropglobals_inner(e,globals) for e in expr.args]...)
    elseif expr.head == :line
        expr
    else
        error("unrecognized $(expr.head) expression in dropglobals_inner")
    end
end

dropglobals_inner(expr::LineNumberNode, _) = expr
dropglobals_inner(expr::QuoteNode, _) = expr
dropglobals_inner(expr::Symbol, _) = expr
dropglobals_inner(expr::Number, _) = expr
