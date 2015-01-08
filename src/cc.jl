export Closure, call, cc, @cc, @cps_cc

# Closure conversion based on:
# http://matt.might.net/articles/closure-conversion/

disp(x) = (println(x);x)

cc(expr::Expr) = expr |> transform |> dropglobals2 |> lift |> translate |> disp

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
    f(e::Symbol) = [e]
    f(e::Expr) = (@assert e.head == :tuple; e.args)

    if expr.head == :->
        f(expr.args[1])
    elseif expr.head == symbol("->*")
        [f(expr.args[1]),f(expr.args[2])]
    end
end


# Convert individual (not-recursively) anonymous fuctions into
# abstract syntax for creating closures.

function closureconvert(expr::Expr)
    if expr.head == :->
        @assert length(expr.args) == 2
        @assert expr.args[2].head == :block
        envsym = gensym("env")
        newargs = Expr(:tuple, envsym, fargs(expr)...)
        fv = free(expr)
        freeargs = [gensym() for _ in 1:length(fv)]
        newargs = Expr(:tuple, fargs(expr)...)
        envargs = Expr(:tuple, freeargs...)
        # TODO: Maybe it's this which is tricky/inconvinient later on?
        #env = Expr(:tuple, v, v) for v in fv]
        subs = Dict([(v,a) for (v,a) in zip(fv,freeargs)])
        newbody = substitute(subs, expr.args[2])
        lambdaexpr = Expr(symbol("->*"), newargs, envargs, newbody)
        Expr(:makeclosure, lambdaexpr, Expr(:makeenv, fv...))
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
        @assert length(expr.args) == 3
        @assert expr.args[3].head == :block
        # TODO: Extract helper.
        args = fargs(expr)
        body = expr.args[2]
        vars = setdiff(free(body), Set(args))
        @assert length(vars) == 0
        Set()
    elseif expr.head in [:block, :comparison, :.,:tuple]
        union(Set(), [free(e) for e in expr.args]...)
    elseif expr.head == :if
        @assert length(expr.args) == 3
        union(Set(), [free(e) for e in expr.args]...)
    elseif expr.head == :line
        Set()
    elseif expr.head == :makeclosure
        union(free(expr.args[1]), free(expr.args[2]))
    elseif expr.head == :makeenv
        union(Set(), [free(e) for e in expr.args]...)
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
        args = fargs(expr)#isa(expr.args[1], Symbol) ? [expr.args[1]] : expr.args[1].args
        s = filter((k,v) -> !(k in args), subs)
        Expr(symbol("->*"), expr.args[1], expr.args[2], substitute(s, expr.args[3]))
    elseif expr.head in [:block, :comparison, :.,:tuple,:makeenv]
        Expr(expr.head, [substitute(subs,e) for e in expr.args]...)
    elseif expr.head == :if
        Expr(:if, [substitute(subs,e) for e in expr.args]...)
    elseif expr.head == :makeclosure
        Expr(:makeclosure, substitute(subs, expr.args[1]), substitute(subs, expr.args[2]))
    # elseif expr.head == :makeenv
    #     Expr(:makeenv, [Expr(:tuple, e.args[1], substitute(subs, e.args[2])) for e in expr.args]...)
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
        Expr(:makeenv, [t(e) for e in expr.args]...)
#    elseif expr.head == :envref
#        Expr(:envref, t(expr.args[1]), expr.args[2])
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
            args = [expr.args[1].args[1].args, expr.args[1].args[2].args]
            body = iter(expr.args[1].args[3])
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
    env::Tuple#::Dict{Symbol,Any} Now "extra args"
end

Base.call(c::Closure, args...) = c.f(args...,c.env...)

#call(f::Union(Function,Type), args...) = f(args...)

function translate(expr::Expr)
    if expr.head == :makeclosure
        f = expr.args[1]::Symbol
        env = translate(expr.args[2])
        :(Closure($f, $env))
    elseif expr.head == :makeenv
        # tupleexpr = Expr(:tuple)
        # for e in expr.args
        #     @assert e.head == :tuple
        #     push!(tupleexpr.args, translate(e.args[2]))
        # end
        # tupleexpr
        Expr(:tuple, expr.args...)
    # elseif expr.head == :envref
    #     env = expr.args[1]
    #     var = expr.args[2]
    #     Expr(:ref, env, QuoteNode(var))
    #     var
    elseif expr.head == :applyclosure
        #:(call($([translate(e) for e in expr.args]...)))
        Expr(:call, [translate(e) for e in expr.args]...)
    elseif expr.head in [:block,:function,:call,:if,:comparison,:.,:tuple]
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
        #Expr(:makeclosure, dropglobals_inner(expr.args[1], globals), Expr(:makeenv))
        newexpr, _ = dropglobals_main(expr, globals)
        #globals = [globals, dropped]
        Expr(:makeclosure, dropglobals_inner(newexpr.args[1],globals), newexpr.args[2])
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

function dropglobals_inner(expr::Expr, globals::Vector)
    if expr.head == :envref
        expr.args[2] in globals ? expr.args[2] : expr
    elseif expr.head == :makeenv
        Expr(:makeenv, filter(e->!(e.args[1c] in globals), expr.args)...)
        #expr
    elseif expr.head == symbol("->*")
        args = expr.args[1].args
        g = filter(v->!(v in args), globals)
        Expr(expr.head, [dropglobals_inner(e,g) for e in expr.args]...)
    elseif expr.head in [:tuple,:block,:if,:comparison,:.]
        Expr(expr.head, [dropglobals_inner(e,globals) for e in expr.args]...)
    elseif expr.head == :applyclosure
        # println(expr)
        # println(globals)
        expr
    elseif expr.head == :makeclosure
        newexpr, dropped = dropglobals_main(expr, globals)
        #newglobals = [globals, dropped]
        Expr(expr.head, [dropglobals_inner(e,globals) for e in newexpr.args]...)
        
        #Expr(expr.head, [dropglobals_inner(e,globals) for e in expr.args]...)
    elseif expr.head == :line
        expr
    else
        error("unrecognized $(expr.head) expression in dropglobals_inner")
    end
end

dropglobals_inner(expr::LineNumberNode, _) = expr
dropglobals_inner(expr::QuoteNode, _) = expr
dropglobals_inner(expr::Symbol, globals) = expr
dropglobals_inner(expr::Number, _) = expr

function dropglobals_main(expr::Expr, globals)
    @assert expr.head == :makeclosure
    envtuplesexpr = expr.args[2].args
    n = length(envtuplesexpr)
    argsexpr = expr.args[1].args[1].args[1:end-n]
    envargsexpr = expr.args[1].args[1].args[end-(n-1):end]
    # println(expr)
    # println()
    # println(argsexpr)
    # println(envargsexpr)
    # println()
    # dump(envtuplesexpr)
    # println()

    f = collect(filter(pair->(!(pair[2].args[1] in globals)), zip(envargsexpr, envtuplesexpr)))
    if length(f) == 0
        a,b=(),()
    else
        a,b = zip(f...)
    end



    
    dropped = collect(filter(pair->((pair[2].args[1] in globals)), zip(envargsexpr, envtuplesexpr)))
    # if length(dropped) > 0
    #     dropped = collect(zip(dropped...))
    # end
    
    bodyexpr = expr.args[1].args[2]
    # println("Dropped: $dropped")
    for d in dropped
        from = d[1]
        to = d[2].args[1]
        #println("$from => $to")
        body = substitute([from=>to], bodyexpr)
        
    end

    # println(a)
    # println()
    # println(b)
    # println()

    lambdaexpr = Expr(symbol("->*"), Expr(:tuple, [argsexpr,a...]...), bodyexpr)
    envexpr = Expr(:makeenv, b...)


    Expr(:makeclosure, lambdaexpr, envexpr), []
end

    
function dropglobals2(expr::Expr)
    if expr.head == :makeclosure
        #println(expr)
        @assert expr.args[1].head == symbol("->*")
        globals = expr.args[2].args # from env
        subs = Dict(expr.args[1].args[2].args, globals)
        #println("Top-level subs: $subs")
        lambdaexpr = Expr(symbol("->*"), expr.args[1].args[1], Expr(:tuple),
                          dropglobals2_inner(fullsub(expr.args[1].args[3], subs), globals))
        envexpr = Expr(:makeenv)
        Expr(expr.head, lambdaexpr, envexpr)
    #elseif expr.head in [:block,:applyclosure,:.]

    elseif expr.head == :line
        expr
    else
        Expr(expr.head, [dropglobals2(e) for e in expr.args]...)
        # error("unrecognised $(expr.head) expression in dropglobals")
    end
end

dropglobals2(expr::Symbol) = expr
dropglobals2(expr::QuoteNode) = expr
dropglobals2(expr::LineNumberNode) = expr

function fullsub(expr::Expr, subs)
    Expr(expr.head, [fullsub(e,subs) for e in expr.args]...)
end

fullsub(expr::Symbol, subs) = get(subs,expr,expr)
fullsub(expr, _) = expr


function dropglobals2_inner(expr::Expr, globals)
    if expr.head == :makeclosure
        eargs  = expr.args[1].args[2].args
        env = expr.args[2].args
        subs = Dict()
        env2 = Any[]
        eargs2 = Symbol[]
        for (e,a) in zip(env,eargs)
            if e in globals
                subs[a] = e
            else
                # keep arg/env
                push!(env2,e)
                push!(eargs2,a)
            end
        end
        lambdaexpr = Expr(symbol("->*"), expr.args[1].args[1],
                          Expr(:tuple, eargs2...),
                          dropglobals2_inner(fullsub(expr.args[1].args[3], subs), globals))
        envexpr = Expr(:makeenv, env2...)
        Expr(expr.head, lambdaexpr, envexpr)
    elseif expr.head == :line
        expr
    else
        Expr(expr.head, [dropglobals2_inner(e, globals) for e in expr.args]...)
    end
end

dropglobals2_inner(expr::Symbol,_) = expr
dropglobals2_inner(expr::QuoteNode,_) = expr
dropglobals2_inner(expr::LineNumberNode,_) = expr
dropglobals2_inner(expr::Number, _) = expr        

        

