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
