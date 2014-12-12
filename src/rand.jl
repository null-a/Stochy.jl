import Base.Random.rand

function rand(ps::Vector{Float64})
    @assert isdistribution(ps)
    acc = 0.
    r = rand()
    for (i,p) in enumerate(ps)
        acc += p
        if r < acc
            return i
        end
    end
    error("unreachable")
end
