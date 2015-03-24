export pmcmc, smc

immutable Step
    thunk::Function
    score::Float64
end

type Particle
    path::Vector{Step}
    value
end

Particle(thunk) = Particle([Step(thunk, 0)], nothing)

type PMCMC <: Ctx
    numparticles::Int64
    thunk::Function
    currentindex::Int64
    retainedparticle::Union(Nothing,Particle)
    particles::Vector{Particle}
    function PMCMC(numparticles, thunk)
        ctx = new(numparticles, thunk, 1, nothing)
        resetparticles!(ctx)
        ctx
    end
end

function resetparticles!(ctx::PMCMC)
    ctx.particles = [Particle(ctx.thunk) for _ in 1:ctx.numparticles]
end

function sample(s::Store, k::Function, address, e::ERP, ::PMCMC)
    k(s,rand(e))
end

function factor(s::Store, k::Function, address, score, ctx::PMCMC)
    push!(ctx.particles[ctx.currentindex].path, Step(()->k(s,nothing), score))
    if ctx.currentindex < length(ctx.particles)
        ctx.currentindex += 1
    else
        @assert length(unique([length(p.path) for p in ctx.particles])) == 1
        ctx.particles = resample(ctx.particles, ctx.retainedparticle)
        ctx.currentindex = 1
    end
    ctx.particles[ctx.currentindex].path[end].thunk()
end

function resample(particles, weights, n)
    @assert length(particles) == length(weights)
    ps = weights/sum(weights)
    Particle[deepcopy(particles[rand(ps)]) for _ in 1:n]
end

function resample(particles, ::Nothing)
    weights = Float64[exp(p.path[end].score) for p in particles]
    resample(particles, weights, length(particles))
end

function resample(particles, retainedparticle::Particle)
    currentstep = length(particles[1].path)
    truncparticle = Particle(retainedparticle.path[1:currentstep], retainedparticle.value)
    allparticles = [particles, truncparticle]
    @assert length(unique([length(p.path) for p in allparticles])) == 1
    weights = Float64[exp(p.path[end].score) for p in allparticles]
    resample(allparticles, weights, length(particles))
end

function pmcmcexit(store::Store, value)
    ctx.particles[ctx.currentindex].value = value
    if ctx.currentindex < length(ctx.particles)
        ctx.currentindex += 1
        ctx.particles[ctx.currentindex].path[end].thunk()
    else
        ctx.currentindex = 1
    end
end

function pmcmc(store::Store, k::Function, address, comp::Function, numiterations, numparticles)
    global ctx
    counts = Dict{Any,Int64}()
    ctxold, ctx = ctx, PMCMC(numparticles, ()->comp(store,pmcmcexit,address))
    try
        for i in 1:numiterations
            # Check some invariants.
            @assert ctx.currentindex == 1
            @assert (i==1?==:!=)(ctx.retainedparticle, nothing)
            @assert all(p->length(p.path)==1 && p.value == nothing, ctx.particles)
            trampoline(ctx.particles[ctx.currentindex].path[end].thunk)
            ctx.retainedparticle = ctx.particles[1]
            for p in ctx.particles
                counts[p.value] = get(counts, p.value, 0) + 1
            end
            resetparticles!(ctx)
        end
    finally
        ctx = ctxold
    end
    k(store, Discrete(counts))
end

# PMCMC uses plain SMC (i.e. no retained particle) for the first
# iteration.
smc(store::Store, k::Function, a, comp::Function, n) = pmcmc(store,k,a,comp,1,n)
