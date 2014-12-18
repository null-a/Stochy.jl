import Base.show
export Bernoulli, Categorical, Normal, Dirichlet, flip, randominteger, uniform, normal, dirichlet, categorical, hellingerdistance

isprob(x::Float64) = 0 <= x <= 1
# TODO: Perhaps the epsilon should be based on length(xs)?
isdistribution(xs::Vector{Float64}) = all(isprob, xs) && abs(sum(xs)-1) < 1e-10

function showfield(io::IO, x, field)
    show(io,typeof(x))
    print(io,"(")
    show(io,getfield(x,field))
    print(io,")")
end

abstract ERP

immutable Bernoulli <: ERP
    p::Float64
    function Bernoulli(p::Float64)
        @assert isprob(p)
        new(p)
    end
end

# @pp
Bernoulli(p::Float64, k::Function) = k(Bernoulli(p))

sample(erp::Bernoulli) = rand() < erp.p
support(::Bernoulli) = (true,false)
score(erp::Bernoulli, x::Bool) = x ? log(erp.p) : log(1-erp.p)

@pp function flip(p)
    sample(Bernoulli(p))
end

@pp function flip()
    flip(0.5)
end


immutable Categorical <: ERP
    ps::Vector{Float64}
    xs
    map # Where map[xs[i]] = ps[i].
    function Categorical(ps,xs,map)
        @assert isdistribution(ps)
        @assert length(xs) == length(ps)
        new(ps,xs,map)
    end
end

# Over 1..K.
Categorical(ps) = Categorical(ps,1:length(ps),ps)
# Arbitrary support.
Categorical(ps,xs) = Categorical(ps,xs,Dict(xs,ps))
Categorical(d::Dict) = Categorical(collect(values(d)), collect(keys(d)), d)

# @pp
Categorical(ps,k::Function) = k(Categorical(ps))
Categorical(ps,xs,k::Function) = k(Categorical(ps,xs))
categorical(ps,k::Function) = sample(Categorical(ps), k)
categorical(ps,xs,k::Function) = sample(Categorical(ps,xs), k)


# TODO: Special case for uniform categorical? (Similar to randominteger.)
# Categorical(K=5) for uniform over 1..5?
# Categorical([:a,:b,:c]) for uniform over [..]?
# How do I distinguish the latter from Categorical([0.1,0.2,0.7])?
 
sample(erp::Categorical) = erp.xs[rand(erp.ps)]
score(erp::Categorical, x) = log(erp.map[x])
support(erp::Categorical) = erp.xs

show(io::IO, erp::Categorical) = showfield(io, erp, :map)

# @pp
function randominteger(n, k::Function)
    sample(Categorical(fill(1/n,n)), k)
end

immutable Empirical <: ERP
    counts::Dict{Any,Int64} # Sample counts.
    xs::Vector
    ps::Vector{Float64}
    n::Int64
    function Empirical(counts)
        xs = collect(keys(counts))
        ps = collect(values(counts))
        n = sum(ps)
        ps /= n
        new(counts, xs, ps, n)
    end
end

sample(erp::Empirical) = erp.xs[rand(erp.ps)]

# This is potentially misleading as we can't distinguish between an x
# that isn't in the support and one which has zero probability. Could
# the support be infered by looking at the distribution from which the
# sampled variables were originally drawn?

support(erp::Empirical) = keys(erp.counts)
score(erp::Empirical, x) = log(erp.counts[x]/erp.n)

show(io::IO, erp::Empirical) = showfield(io, erp, :counts)

function recoversamples(erp::Empirical)
    ret = Array(Any, erp.n)
    i = 1
    for (x,c) in erp.counts
        for _ in 1:c
            ret[i] = x
            i += 1
        end
    end
    ret
end

immutable StandardUniform <: ERP; end

sample(::StandardUniform) = rand()
score(::StandardUniform, _) = 0.0

# @pp
uniform(k) = sample(StandardUniform(), k)


immutable Normal <: ERP
    mean::Float64 # mu
    var::Float64  # sigma^2
    function Normal(mean, var)
        @assert var > 0.0
        new(mean,var)
    end
end

# @pp
Normal(mean,var,k) = k(Normal(mean,var))

sample(erp::Normal) = randn() * sqrt(erp.var) + erp.mean
# Un-normalized score.
score(erp::Normal, x) = (x-erp.mean)^2 / (-2. * erp.var)

# @pp
normal(mean, var, k) = sample(Normal(mean, var), k)


immutable Dirichlet <: ERP
    alpha::Vector{Float64}
    function Dirichlet(alpha)
        @assert length(alpha) > 1
        @assert all([a>0 for a in alpha])
        new(alpha)
    end
end

# Symmetric Dirichlet.
Dirichlet(alpha::Float64,K::Int64) = Dirichlet(fill(alpha,K))

sample(erp::Dirichlet) = randdirichlet(erp.alpha)
# Un-normalized score.
score(erp::Dirichlet, x) = error("not implemented")

# @pp
dirichlet(alpha, k::Function) = sample(Dirichlet(alpha), k)
dirichlet(alpha, K, k::Function) = sample(Dirichlet(alpha,K), k)


hellingerdistance(p::Empirical,q::Empirical) = error("not implemented")

function hellingerdistance(p::ERP, q::Empirical)
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
