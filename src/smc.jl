export smc

type Particle
    cont::Function
    score::Float64
    value
    Particle(cont) = new(cont, 0, nothing)
end

type SMC <: Ctx
    particles::Array{Particle}
    currentindex::Int64
    SMC(numparticles, cont) = new([Particle(cont) for _ in  1:numparticles], 1)
end

function sample(e::ERP, k::Function, ::SMC)
    k(sample(e))
end

function factor(score, k::Function, ctx::SMC)
    ctx.particles[ctx.currentindex].score += score
    ctx.particles[ctx.currentindex].cont = () -> k(nothing)
    if ctx.currentindex < length(ctx.particles)
        ctx.currentindex += 1
    else
        ctx.particles = resample(ctx.particles)
        ctx.currentindex = 1
    end
    ctx.particles[ctx.currentindex].cont()
end

function smcexit(value)
    ctx.particles[ctx.currentindex].value = value
    if ctx.currentindex < length(ctx.particles)
        ctx.currentindex += 1
        ctx.particles[ctx.currentindex].cont()
    end
end

function resample(particles::Array{Particle})
    ws = Float64[exp(p.score) for p in particles]
    ps = ws/sum(ws)
    [Particle(particles[rand(ps)].cont) for _ in 1:length(particles)]
end

function smc(comp::Function, numparticles, k::Function)
    global ctx
    local hist
    ctxold, ctx = ctx, SMC(numparticles, () -> comp(smcexit))
    try
        ctx.particles[ctx.currentindex].cont()
        hist = Dict{Any,Float64}()
        for p in ctx.particles
            hist[p.value] = get(hist, p.value, 0) + 1
        end
        normalize!(hist)
    finally
        ctx = ctxold
    end
    Discrete(hist, k)
end
