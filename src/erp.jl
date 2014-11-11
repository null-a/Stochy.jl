import Base.show
import Base.Random.rand
export Bernoulli, Categorical, flip

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

isprob(x::Float64) = 0 <= x <= 1
isdistribution(xs::Vector{Float64}) = all(isprob, xs) && abs(sum(xs)-1) < 1e-15

abstract ERP

immutable Bernoulli <: ERP
    p::Float64
    function Bernoulli(p::Float64)
        @assert isprob(p)
        new(p)
    end
end

# @appl
Bernoulli(p::Float64, k::Function) = k(Bernoulli(p))

sample(erp::Bernoulli) = rand() < erp.p ? 1 : 0
support(::Bernoulli) = (0,1)
score(erp::Bernoulli, x) = x==1 ? log(erp.p) : x==0 ? log(1-erp.p) : error("x not in support")

@appl function flip(p)
    sample(Bernoulli(p))
end

@appl function flip()
    flip(0.5)
end

immutable Discrete <: ERP
    hist::Dict{Any,Float64}
    xs::Array
    ps::Array{Float64}
    function Discrete(hist)
        # TODO: I'm assuming that keys/values iterate over the dict in
        # the same order. Check that they do otherwise values will
        # have their probabilities mixed up.
        xs = collect(keys(hist))
        ps = collect(values(hist))
        @assert isdistribution(ps)
        new(hist, xs, ps)
    end
end

# @appl
Discrete(hist, k::Function) = k(Discrete(hist))

sample(erp::Discrete) = erp.xs[rand(erp.ps)]
support(erp::Discrete) = erp.xs
score(erp::Discrete, x) = log(erp.hist[x])

function show(io::IO, erp::Discrete)
    print(io, "Discrete(")
    show(io, filter((x,p)->p>0,erp.hist))
    print(io, ")")
end
