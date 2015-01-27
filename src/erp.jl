function import_distributions(t=Distribution, count=0)
    for dist in subtypes(t)
        name = dist.name.name
        obj = Distributions.(name)
        if isgeneric(obj)
            # Concrete.
            eval(parse("import Distributions: $name; export $name"))
            eval(:($name(s::Store, k::Function, args...) = k(s, $name(args...))))
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

immutable Discrete
    x::Vector
    p::Vector{Float64}
    dict::Dict # Potentially un-normalized.
    z::Float64 # Normalizing constant.
    function Discrete(dict)
        x = collect(keys(dict))
        p = collect(values(dict))
        z = sum(p)
        z != 1.0 && (p /= z)
        new(x,p,dict,z)
    end
end

rand(erp::Discrete) = erp.x[rand(erp.p)]
support(erp::Discrete) = erp.x
score(erp::Discrete, x) = log(erp.dict[x]/erp.z)

# @pp
Discrete(s::Store, k::Function, x, p) = k(s, Discrete(Dict(x,p)))

# This is experimental and maybe removed. It repeatedly calls a thunk
# and wraps the result in an ERP. This seems convinient as existing
# function can be used to plot the results. This has different
# semantics to pmcmc(1,n,thunk) which simulates n executions of the
# program in which thunk is called once, rather than been a single
# execution of a program which calls the thunk n times.

# @pp
function Discrete(s::Store, k::Function, comp::Function, n)
    partial(repeat, s)(comp, n) do store::Store, samples
        counts = Dict{Any,Int64}()
        for s in samples
            counts[s] = get(counts,s,0) + 1
        end
        k(store, Discrete(counts))
    end
end

function show(io::IO, erp::Discrete)
    print(io, "Discrete(")
    show(io, erp.x)
    print(io, ", ")
    show(io, erp.p)
    print(io, ")")
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
