using Base.Meta
export @cps

const compops = [symbol("=="), :>, :<, :>=, :<=]

Atom = Union(Number, Bool, Symbol, String, QuoteNode)

function cps(expr, cont)
    strippedexpr = striplineinfo(expr)
    cpsexpr = tc(strippedexpr, cont)
    # Trampolining function definitions prevent them from been added
    # to the calling scope.
    if isfuncdef(strippedexpr)
        cpsexpr
    else
        :(Stochy.trampoline(Stochy.Thunk(() -> $cpsexpr)))
    end
end

# This assumes line numbers have been stripped.
function isfuncdef(expr::Expr)
    expr.head == :function ||
    expr.head == :block && !isempty(expr.args) && isfuncdef(expr.args[1])
end

isfuncdef(expr) = false

macro cps(expr)
    cpsexpr = cps(expr, :identity)
    debug() && println(striplineinfo(cpsexpr))
    esc(cpsexpr)
end

# Distinguish thunks from functions returns by the transformed code.
immutable Thunk
    f::Function
    function Thunk(f)
        new(f)
    end
end

function trampoline(t::Thunk)
    thunkcount = 0
    while isa(t, Thunk)
        t = t.f()
        if debug()
            #println(t.f.code)
            thunkcount += 1
        end
    end
    debug() && println("trampolined thunks: ", thunkcount)
    t
end

# Convenience function used to kick-off trampolining in enum() &
# pmcmc().
trampoline(f::Function) = trampoline(Thunk(f))

# CPS transform based on:
# http://matt.might.net/articles/cps-conversion/
# Essentials of Programming Languages (3rd Ed.) [Friedman & Wand]

# | CPS                   | EoPL              | Might's Scheme CPS |                 |
# | tc                    | cps-of-exp        | T-c                |                 |
# | tk(::Function, expr)  | cps-of-exp/ctx    | T-k                | Ex. 6.30, p225. |
# | tk(::Function, exprs) | cps-of-exps       | T*-k               |                 |
# | m                     | cps-of-simple-exp | M                  |                 |

function tc(expr, cont)
    if isatomic(expr)
        :(Stochy.Thunk(() -> $cont($(m(expr)))))
    elseif expr.head == :block && length(expr.args) == 1
        tc(expr.args[1], cont)
    elseif expr.head == :block && length(expr.args) > 1
        tk(expr.args[1]) do _
            # Build block this way rather than with quoting so line
            # number expressions aren't added, preventing recursion
            # from ever bottoming out.
            tc(Expr(:block, expr.args[2:end]...), cont)
        end
    elseif expr.head == :local
        @assert expr.args[1].head == symbol("=")
        @assert length(expr.args) == 1
        val = expr.args[1].args[2]
        tk(e -> :($cont($e)), val)            
    # elseif expr.head == :let
        # @assert all([arg.head == symbol("=") for arg in expr.args[2:end]])
        # body = expr.args[1]        
        # vars = [arg.args[1]::Symbol for arg in expr.args[2:end]]
        # exprs = [arg.args[2] for arg in expr.args[2:end]]
        # tk(exprs) do e...
        #     :(let $(map((var, val) -> :($(var)=$(val)), vars, e)...); $(tc(body, cont)) end)
        # end
    elseif expr.head == :if
        @assert length(expr.args) == 3
        tk(expr.args[1]) do test
            :($test ? $(tc(expr.args[2], cont)) : $(tc(expr.args[3], cont)))
        end
    elseif expr.head == :function
        f = expr.args[1].args[1]
        args = expr.args[1].args[2:end]
        body = expr.args[2]
        v = gensym()
        :($cont(function $f($v, $(args...)); $(tc(body, v)); end))
    elseif expr.head == :||
        # Convert to if statement.
        @assert length(expr.args) == 2
        lhs, rhs = expr.args
        tc(:($lhs ? true : ($rhs ? true : false)), cont)
    elseif expr.head == :&&
        @assert length(expr.args) == 2
        lhs, rhs = expr.args
        tc(:($lhs ? ($rhs ? true : false) : false), cont)
    elseif isprimop(expr)
        f = expr.args[1]
        tk(expr.args[2:end]) do e...
            :($cont($f($(e...))))
        end
    elseif expr.head == :call
        tk(expr.args) do f, e...
            :($f($cont, $(e...)))
        end
    elseif expr.head == :.
        @assert isa(expr.args[2], QuoteNode) || isa(expr.args[2], Expr)
        @assert length(expr.args) == 2
        # The dot syntax turns in to two different Exprs depending on
        # whether you use the macro or :(<expr>). Handle both.
        if isa(expr.args[2], Expr)
            @assert expr.args[2].head == :quote
            @assert length(expr.args[2].args) == 1
            sym = expr.args[2].args[1]
        else
            @assert isa(expr.args[2].value, Symbol)
            sym = expr.args[2].value
        end
        tk(expr.args[1]) do e
            :($cont($(e).$(sym)))
        end
    elseif expr.head == :comparison && expr.args[2] in compops
        @assert length(expr.args) == 3
        tk([expr.args[1], expr.args[3]]) do x, y
            compexpr = Expr(expr.head, x, expr.args[2], y)
            :($cont($compexpr))
        end
    elseif expr.head == :vcat
        tk(expr.args) do e...
            :($cont([$(e...)]))
        end
    elseif expr.head == :ref
        @assert length(expr.args) == 2
        tk(expr.args) do x, y
            :($cont($x[$y]))
        end
    else
        error("$(expr.head) expression not recognized")        
    end
end

function tk(k::Function, expr::Union(Expr, Atom))
    if isatomic(expr)
        k(m(expr))
    elseif expr.head == :local && isexpr(expr.args[1].args[2], :call)
        # This is an optimization.
        # When the result of a function call is bound to a local
        # variable, bind the variable by using its name as the
        # continuation's argument.
        # e.g. local a = f(x); <expr> => f(x, (a) -> <expr>)
        #
        # This optimization is contained wholly within this elseif.
        v = expr.args[1].args[1]
        callexpr = expr.args[1].args[2]
        tc(callexpr, :($v -> $(k(v))))
    elseif expr.head == :local
        v = expr.args[1].args[1]
        tc(expr, :($v -> $(k(v))))
    elseif expr.head == :...
        v = gensym()
        vsplat = Expr(:..., v)
        tc(expr.args[1], :($v -> $(k(vsplat))))
    else
        v = gensym()
        tc(expr, :($v -> Stochy.Thunk(() -> $(k(v)))))
    end
end

function tk(k::Function, exprs::Array)
    if isempty(exprs)
        k(()...)
    else
        tk(first(exprs)) do e
            tk(exprs[2:end]) do es...
                k(e, es...)
            end
        end
    end
end

function m(expr::Expr)
    @assert isatomic(expr)
    if expr.head == :->
        k = symbol("##k00")
        args = procargs(expr.args[1])
        # This type annotation is required to fix a failing test
        # caused by this issue:
        # https://github.com/JuliaLang/julia/issues/9770
        body = expr.args[2]::Expr
        :(($k, $(args...)) -> $(tc(body, k)))
    elseif expr.head == :quote
        expr
    else
        error("unreachable")
    end
end

m(expr::Atom) = expr

procargs(exp::Expr) = exp.args
procargs(exp) = [exp]

isatomic(exp::Atom) = true
isatomic(exp::Expr) = exp.head == :-> || exp.head == :quote
isatomic(exp) = false

isprimop(exp::Expr) = exp.head == :call && exp.args[1] in primitives

isline(exp::Expr) = exp.head == :line
isline(exp::LineNumberNode) = true
isline(exp) = false

not(pred) = x -> !(pred(x))
split(pos::Int, a::Array) = (a[1:pos-1],a[pos:end])

striplineinfo(exp::Expr) = Expr(exp.head, map(striplineinfo, filter(not(isline), exp.args))...)
striplineinfo(exp) = exp

function desugar(expr::Expr)
    if expr.head == :block
        # Expand local expressions of n variables into n local
        # expressions each introducing a single variable.
        newargs = map(expandlocals, expr.args) |> flatten
        Expr(:block, map(desugar, newargs)...)
    elseif expr.head == :local && length(expr.args) > 1
        # Add a top-level local expression to a block and recurse to
        # expand if required.
        desugar(Expr(:block, expr))
    elseif expr.head == :call && expr.args[1] == :~
        # Re-write calls to ~.
        Expr(:call, :sample, map(desugar, expr.args[2:end])...)
    else
        Expr(expr.head, map(desugar, expr.args)...)
    end
end

desugar(expr::Atom) = expr
desugar(expr::LineNumberNode) = expr

flatten(a) = vcat(a...)

function expandlocals(expr::Expr)
    if expr.head == :local
        map(arg->:(local $(arg.args[1])=$(arg.args[2])), expr.args)
    else
        expr
    end
end

expandlocals(expr::Atom) = expr
expandlocals(expr::LineNumberNode) = expr
