function import_distributions(t=Distribution, count=0)
    for dist in subtypes(t)
        name = dist.name.name
        obj = Distributions.(name)
        if isgeneric(obj)
            # Concrete.
            eval(parse("import Distributions: $name; export $name"))
            eval(:($name(s::Store, k::Function, address, args...) = k(s, $name(args...))))
            count += 1
        else
            # Abstract.
            count += import_distributions(obj, count)
        end
    end
    count
end

_dist_count = import_distributions()

const Dir = Dirichlet

const _flip_map = (false,true)

@pp function flip(args...)
    _flip_map[~Bernoulli(args...)+1]
end

@pp function randominteger(k)
    ~Categorical(k)
end

# Gradient of the score (logpdf) w.r.t. the parameters.
function gradient(erp::Bernoulli, x)
    g = (x-erp.p) / (erp.p*(1-erp.p))
    @assert isfinite(g)
    [g]
end

immutable Discrete
    x::Vector
    p::Vector{Float64}
    dict::Dict # Potentially un-normalized.
    z::Float64 # Normalizing constant.
    function Discrete(dict)
        x = collect(keys(dict))
        p = collect(values(dict))
        z = sum(p)
        z == 0 && error("Distribution has zero probability mass.")
        z != 1.0 && (p /= z)
        new(x,p,dict,z)
    end
end

rand(erp::Discrete) = erp.x[rand(erp.p)]
support(erp::Discrete) = erp.x
score(erp::Discrete, x) = log(erp.dict[x]/erp.z)

# @pp
Discrete(s::Store, k::Function, address, x, p) = k(s, Discrete(Dict(x,p)))

# This is experimental and maybe removed. It repeatedly calls a thunk
# and wraps the result in an ERP. This seems convinient as existing
# function can be used to plot the results. This has different
# semantics to pmcmc(1,n,thunk) which simulates n executions of the
# program in which thunk is called once, rather than been a single
# execution of a program which calls the thunk n times.

# @pp
function Discrete(s::Store, k::Function, address, comp::Function, n)
    partial(repeat, s)(address, comp, n) do store::Store, samples
        counts = Dict{Any,Int64}()
        for s in samples
            counts[s] = get(counts,s,0) + 1
        end
        k(store, Discrete(counts))
    end
end

# Based on Base.showdict
function show(io::IO, erp::Discrete)
    t = sort(collect(zip(erp.p, erp.x)), rev=true)

    xs = Array(String, length(t))
    keylen = 0
    for (i, (_,x)) in enumerate(t)
        xs[i] = sprint(show, x)
        keylen = max(length(xs[i]), keylen)
    end

    for (i, (p,_)) in enumerate(t)
        print(io, rpad(xs[i], keylen, " "))
        print(io, " | ")
        print(io, p)
        i < length(t) && print(io, "\n")
    end
end

const ERP = Union(Distribution, Discrete)

function hellingerdistance(p::ERP, q::Discrete)
    psupp = support(p)
    qsupp = support(q)
    @assert issubset(qsupp, psupp)
    acc = 0.
    for x in psupp
        px = exp(score(p,x))
        qx = x in qsupp ? exp(score(q,x)) : 0.
        acc += (sqrt(px)-sqrt(qx))^2
    end
    sqrt(acc/2.)
end

function kl(p::ERP, q::ERP)
    psupp = support(p)
    qsupp = support(q)
    @assert length(psupp) == length(qsupp)
    for x in psupp; @assert x in qsupp; end
    sum([exp(score(p,x)) * (score(p,x) - score(q,x)) for x in psupp])
end

kl(s::Store, k::Function, address, p::ERP, q::ERP) = k(s, kl(p,q))
