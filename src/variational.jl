export variational, gd, adagrad

# TODO: Check this interacts correctly with mem/store/XRP etc.

type Variational <: Ctx
    params::Dict # The variational parameters.
    gradients::Dict # Local gradients at each ERP.
    variationalscore::Float64
    score::Float64 # Score.
end

Variational() = Variational(Dict(), Dict(), 0, 0)

function sample(s::Store, k::Function, address, erp::ERP, ctx::Variational)
    if !haskey(ctx.params, address)
        # Initialize variational parameters. Distributions.jl returns
        # a tuple of params. Convert to an array in order to use + to
        # accumulate.
        ctx.params[address] = [params(erp)...]
    end

    # Distributions.jl is implemented such that the following will
    # always do the right thing.
    erpv = typeof(erp)(ctx.params[address]...)

    # Sample from the variational program.
    value = rand(erpv)

    @assert !haskey(ctx.gradients, address)
    ctx.gradients[address] = gradient(erpv, value)

    ctx.score += score(erp, value)
    ctx.variationalscore += score(erpv, value)

    k(s,value)
end

function factor(s::Store, k::Function, address, score, ctx::Variational)
    ctx.score += score
    k(s,nothing)
end

variational_exit(s::Store, value) = value

function variational(s::Store, k::Function, address, comp::Function, numsamples=10, maxsteps=100, optimizer=adagrad())
    global ctx
    ctxold, ctx = ctx, Variational()
    ctxreturn = nothing
    init_thunk = () -> comp(s, variational_exit, address)
    converged = false

    try
        for curstep in 1:maxsteps

            L = 0.0
            gradients = Dict()

            for _ in 1:numsamples
                # Reset context state ready for next execution of the
                # variational program, but retain the variational
                # parameters.
                empty!(ctx.gradients)
                ctx.variationalscore = ctx.score = 0.0

                # Run the program.
                value = trampoline(init_thunk)

                # Accumulate objective/gradients.
                weight = ctx.variationalscore - ctx.score
                L += weight
                for (addr, grad) in ctx.gradients
                    gradients[addr] = get(gradients, addr, 0.) + weight*grad
                end
            end

            L /= numsamples
            for (addr, _) in gradients
                gradients[addr] /= numsamples
            end

            #println(L)

            if optimizer(ctx.params, gradients)
                info("Variational inference converged after $curstep steps.")
                converged = true
                break
            end
        end

    finally
        ctx, ctxreturn = ctxold, ctx
    end

    converged || info("Variational inference did not converge after $maxsteps steps.")
    #println(ctxreturn.params)

    # I'm not at all convinced that this is a fully general solution
    # to the problem of creating a variational program from the
    # learned parameters and the thunk passed to inference. You can
    # use this to draw samples and you can pass it to enum, but I've
    # not thought carefully enough about it to be convinced it will
    # work elsewhere.

    partial(k,s)() do s::Store, k::Function, curaddress
        # This is the body of the returned variational program.
        global ctx
        rewritten_params = rewrite_param_addresses(ctxreturn.params, address, curaddress)
        ctx = VarExec(ctx, rewritten_params)
        partial(comp,s)(curaddress) do s2, value
            # This is the body of the continuation passed to the program.
            ctx = ctx.parent
            k(s2,value)
        end
    end

end

# The program returned by variational inference works by executing the
# original program in a context (co-routine in webppl) which
# intercepts calls to sample, substituting the original ERP for the
# variational ERP.

type VarExec <: Ctx
    parent::Ctx
    params::Dict
end

function sample(s::Store, k::Function, address, erp::ERP, varctx::VarExec)
    # Switch out the ERP for the variational ERP.
    erpv = typeof(erp)(varctx.params[address]...)
    partial(sample,s)(address,erpv,varctx.parent) do s2, value
        # When performing enumeration over a variational program the
        # context will have been reset when the variational program is
        # resumed. It's therefore necessary to reset the context to
        # the variational context here.
        global ctx
        ctx = varctx
        k(s2,value)
    end
end

factor(s::Store, k::Function, address, score, ctx::VarExec) = k(s,nothing)

# It's necessary to re-write the addresses of the params dictionary
# when executing the variational program returned by inference. This
# is because the variational program will be executed from a different
# point in the program than infererence was performed at. This needs
# to be accounted for when looking up the variational parameters for
# an ERP during execution of the learned variational program.

function rewrite_param_addresses(params, oldprefix, newprefix)
    oldp = reverse(oldprefix)
    newp = reverse(newprefix)
    rewrite = address -> reverse(rewrite_address(reverse(address), oldp, newp))
    newparams = Dict()
    for (addr, param) in params
        newparams[rewrite(addr)] = param
    end
    newparams
end

function rewrite_address(address, oldprefix, newprefix)
    # All 3 args are expected to be reversed by the caller.
    if isempty(oldprefix)
        cat(newprefix, address)
    else
        @assert first(oldprefix) == first(address)
        rewrite_address(tail(address), tail(oldprefix), newprefix)
    end
end

# Optimizers.

# Gradient descent.
gd(stepsize=0.1) = (params, gradients) -> gdstep!(params, gradients, stepsize)
gd(s::Store, k::Function, address, args...) = k(s, gd(args...))

function gdstep!(params, gradients, stepsize)
    for (addr, grad) in gradients
        params[addr] -= stepsize * grad
    end
    false # TODO: Test for convergence.
end

function adagrad(stepsize=0.1, eps=1e-6)
    history = Dict()
    delta_avg = 0. # Running averge of the magnitude of the step taken.
    (params, gradients) -> begin
        delta = adagradstep!(params, gradients, history, stepsize)
        delta_avg = 0.9*delta_avg + 0.1*delta
        delta_avg < eps # Convergence test.
    end
end

adagrad(s::Store, k::Function, address, args...) = k(s, adagrad(args...))

function adagradstep!(params, gradients, history, stepsize)
    # This assumes that any parameter not in the gradients dictionary
    # has gradient zero gradient.

    # TODO: Is there a better way to test for convergence? I'm not
    # sure this makes much sense for all parameter spaces. e.g. When a
    # parameters live in [0,1] rather than ℝ.

    # TODO: Figure out a principled (and generally applicable) way to
    # prevent updates setting parameters to nonsensical values.

    delta = 0.
    numdims = 0
    for (addr, grad) in gradients
        h = get(history, addr, 0.0) + grad.^2
        history[addr] = h
        step = (stepsize./√h) .* grad
        params[addr] -= step
        delta += sum(step.^2)
        numdims += length(step)
    end
    delta / numdims
end
