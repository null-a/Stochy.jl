export mh

immutable Choice
    store::Store
    k::Function
    address
    erp::ERP
    score::Float64
    value
    choicescore::Float64
    fresh::Bool # true when re-sampled.
end

type MH <: Ctx
    choices::Vector{Choice}
    oldchoices::Vector{Choice}
    score::Float64
end

MH() = MH(Choice[], Choice[], 0)

function sample(s::Store, k::Function, address, e::ERP, ctx::MH, force=false)
    # This makes a step run in O(n^2) time. (Though the constants are
    # really huge anyway.) For larger state spaces it might be worth
    # using an ordered dictionary.
    if force || ((ix = findfirst(c -> c.address == address, ctx.oldchoices)) == 0)
        value = rand(e)
        fresh = true
    else
        value = ctx.oldchoices[ix].value
        fresh = false
    end
    choicescore = score(e, value)
    push!(ctx.choices, Choice(s,k,address,e,ctx.score,value,choicescore,fresh))
    # Update score /after/ storing current score in choices in-case of restart.
    ctx.score += choicescore
    k(s,value)
end

function factor(s::Store, k::Function, a, score, ctx::MH)
    ctx.score += score
    k(s,nothing)
end

mhexit(s::Store, value) = value

function mh(store::Store, k::Function, address, comp::Function, numsteps=10)
    global ctx
    counts = Dict{Any,Int64}()
    ctxold, ctx = ctx, MH()
    try
        # TODO: Consider introducing a compound type to hold choices,
        # score, value. It could support indexing so that state[1:j]
        # does the right thing.

        # Initialize.
        oldvalue = trampoline(() -> comp(store, mhexit, address))
        oldscore = ctx.score
        ctx.oldchoices = ctx.choices

        for i in 1:numsteps
            j = rand(1:length(ctx.oldchoices))
            restartchoice = ctx.oldchoices[j]

            # Restore state prior to re-start point.
            ctx.choices = ctx.oldchoices[1:j-1]
            ctx.score = restartchoice.score

            # Re-start.
            value = trampoline() do
                sample(restartchoice.store,
                       restartchoice.k,
                       restartchoice.address,
                       restartchoice.erp,
                       ctx, true)
            end

            if rand() < min(1., exp(log_mh_ratio(ctx.choices, ctx.oldchoices,
                                                 ctx.score, oldscore, j)))
                # Accept proposal.
                ctx.oldchoices = ctx.choices
                oldscore = ctx.score
                oldvalue = value
            end

            # Update counts.
            counts[oldvalue] = get(counts, oldvalue, 0) + 1
        end
    finally
        ctx = ctxold
    end
    k(store, Discrete(counts))
end

function log_mh_ratio(choices, oldchoices, score, oldscore, j)
    fw = -log(length(oldchoices))
    for c in choices[j:end]
        if c.fresh
            fw += c.choicescore
        end
    end
    bw = -log(length(choices))
    # This is also O(n^2) per-step.
    for c in oldchoices[j:end]
        ix = findfirst(d -> d.address == c.address, choices)
        if ix==0 || choices[ix].fresh
            bw += c.choicescore
        end
    end
    score - oldscore + bw - fw
end
