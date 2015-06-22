export pf

# The store should be handled by the delimited continuation
# implementation but I've not tested it.

type PF_Particle
    k::Union(Nothing, Function) # Continuation, runs the particle.
    weight::Float64
end

PF_Particle() = PF_Particle(nothing, 0)

type PF <: Ctx
    particles::Vector{PF_Particle}
    i::Int64 # Current particle.
    num_particles::Int64
    PF(num_particles) = new([PF_Particle() for _ in 1:num_particles], 1, num_particles)
end

# @pp
PF(s::Store, k::Function, n) = k(s, PF(n))


@pp function pf(comp::Function, num_particles)
    incontext(PF(num_particles)) do
        local returns = Dict()

        reset() do
            # All particles begin here.
            shift() do k
                set_all_continuations!(k)
                current_particle().k(nothing)
            end

            # Run the program.
            local result = comp()

            # Store the result.
            setindex!(returns, get(returns, result, 0) + exp(getstore(:score)), result)

            # println("*****************")
            # println("Exited with: ")
            # println(result)
            # println(current_particle())
            # println("*****************")

            # Run any remaining particles.
            if ctx.i < ctx.num_particles
                inc_counter!()
                current_particle().k(nothing)
            else
                println("All particles have finished")
            end
        end
        Discrete(returns)
    end
end

# sample isn't written in stochy. Though for the purpose of
# demonstrating delimited continuations it makes no difference since
# it doesn't do anything interesting with control.

# @pp
function sample(s::Store, k::Function, erp::ERP, ctx::PF)
    k(s, rand(erp))
end

@pp function factor(score, ctx::PF)
    #println(current_particle())
    #println(score)
    set_weight!(current_particle(), score)
    shift() do k
        # Set the current particle to continue from here.
        set_continuation!(current_particle(), k)
        # Advance counter to next particle.
        inc_counter!()
        # Resample before continuing with the first particle
        (ctx.i == 1) ? resample!() : nothing
        current_particle().k(nothing)
    end
end

@pp function current_particle()
    ctx.particles[ctx.i]
end



# The following supporting functions are written in Julia. Most of
# them deal with mutation and data structures and could be mode to
# Stochy as the language develops.

function resample!(s::Store, k::Function)
    #println("resampling!")
    weights = Float64[exp(p.weight) for p in ctx.particles]
    weights = weights / sum(weights)
    ctx.particles = [copyparticle(ctx.particles[rand(weights)]) for _ in 1:ctx.num_particles]
    k(s, nothing)
end

copyparticle(p::PF_Particle) = PF_Particle(p.k, 0.)

function set_all_continuations!(s::Store, k::Function, cont)
    for i in 1:ctx.num_particles
        ctx.particles[i].k = cont
    end
    k(s, nothing)
end

# @pp
function inc_counter!(s::Store, k::Function)
    ctx.i += 1
    if ctx.i > ctx.num_particles
        ctx.i = 1
    end
    k(s, nothing)
end

# @pp
function set_weight!(s::Store, k::Function, p::PF_Particle, w)
    p.weight = w
    k(s, nothing)
end

# @pp
function set_continuation!(s::Store, k::Function, p::PF_Particle, cont)
    p.k = cont
    k(s, nothing)
end
