export enumdelimited

type EnumDelimited <: Ctx
    unexplored
    EnumDelimited() = new(list())
end

# @pp
EnumDelimited(s::Store, k::Function) = k(s, EnumDelimited())

# Exhaustive inference written in Stochy using delimited continuations.

@pp function enumdelimited(comp::Function)
    incontext(EnumDelimited()) do
        local entryscore = getstore(:score)
        setstore!(:score, 0.)
        local returns = Dict()
        reset() do
            local result = comp()
            setindex!(returns, get(returns, result, 0) + exp(getstore(:score)), result)
            runnextdelimited()
        end
        setstore!(:score, entryscore)
        Discrete(returns)
    end
end

@pp function sample(erp::ERP, ctx::EnumDelimited)
    local value = shift() do k
        foreach(support(erp)) do value
            enqctx!() do
                k(value)
            end
        end
        runnextdelimited()
    end
    local currentscore = getstore(:score)
    setstore!(:score, currentscore + score(erp, value))
    value
end

@pp function factor(score, ctx::EnumDelimited)
    local currentscore = getstore(:score)
    setstore!(:score, currentscore + score)
end

# While enumeration, sample and factor are all written in Stochy the
# following supporting functions are written in Julia. Most of them
# deal with mutation and data structures and could be mode to Stochy
# as the language develops.

# @pp
function incontext(s::Store, k::Function, f::Function, context::Ctx)
    # NOTE: This doesn't restore the context when an exception occurs.
    # Perhaps that should happen in one place higher up the stack,
    # perhaps in @pp?
    global ctx
    ctxold, ctx = ctx, context
    partial(f,s)() do s2, val
        ctx = ctxold
        # TODO: Consider continuing with s2 rather than s.

        # I think I effectively already do so in enum.

        # s2 may contain modifications to the store made during
        # inference. Exactly what modifications are present at the end
        # of inference may depend on details of the inference
        # procedure. e.g. search strategy in enumeration. This doesn't
        # seem to be the right thing to do. Further, caching the
        # results of enumeration may be problematic if the store is
        # modified during inference, as performing inference is no
        # longer equivalent to returning a cached ERP. (Returning the
        # cached ERP won't modify the store.)
        k(s2,val)
    end
end

# @pp
function enqctx!(s::Store, k::Function, thunk::Function)
    ctx.unexplored = cons(thunk, ctx.unexplored)
    k(s, nothing)
end

# @pp
function deqctx!(s::Store, k::Function)
    item = first(ctx.unexplored)
    ctx.unexplored = tail(ctx.unexplored)
    k(s, item)
end

@pp function runnextdelimited()
    if length(ctx.unexplored) == 0
        :done
    else
        deqctx!()()
    end
end

# get and setindex! are added as primitives.
import Base.Dict
Dict(s::Store,k::Function) = k(s,Dict())

# @pp
function getstore(s::Store, k::Function, var::Symbol)
    # Special handling of score to avoid handling it not been set at
    # the first level of inference. (Which would be clunk in Stochy at
    # present.) Perhaps this should be set when the store is created.
    # (Assuming it remains in the store and doesn't move into the
    # context.)
    if var == :score
        k(s, get(s,var,0.))
    else
        k(s, s[var])
    end
end

# @pp
function setstore!(s::Store, k::Function, var::Symbol, val)
    # Copy-on-write.
    s = copy(s)
    s[var] = val
    k(s, nothing)
end

# The only reason this isn't written in Stochy is I don't have ":"
# expressions yet.

# @pp
function foreach(s::Store, k::Function, f::Function, xs)
    if length(xs) == 0
        k(s, nothing)
    else
        partial(f,s)(xs[1]) do s2, _
            foreach(s2, k, f, xs[2:end])
        end
    end
end
