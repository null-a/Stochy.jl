import Base.show
export Bernoulli, Categorical, Normal, Dirichlet, Beta, Empirical, flip, randominteger, uniform, normal, dirichlet, categorical, samplebeta, hellingerdistance

isprob(x::Float64) = 0 <= x <= 1
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
Bernoulli(k::Function, p::Float64) = k(Bernoulli(p))

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
Categorical(k::Function,ps) = k(Categorical(ps))
Categorical(k::Function,ps,xs) = k(Categorical(ps,xs))
categorical(k::Function,ps) = sample(k, Categorical(ps))
categorical(k::Function,ps,xs) = sample(k, Categorical(ps,xs))

sample(erp::Categorical) = erp.xs[rand(erp.ps)]
score(erp::Categorical, x) = log(erp.map[x])
support(erp::Categorical) = erp.xs

show(io::IO, erp::Categorical) = showfield(io, erp, :map)

# @pp
function randominteger(k::Function, n)
    sample(k, Categorical(fill(1/n,n)))
end

immutable Empirical <: ERP
    counts::Dict{Any,Int64} # Sample counts.
    xs::Vector
    ps::Vector{Float64}
    n::Int64
end

function Empirical(counts::Dict)
    xs = collect(keys(counts))
    ps = collect(values(counts))
    n = sum(ps)
    ps /= n
    Empirical(counts, xs, ps, n)
end

# This is experimental and maybe removed. It repeatedly calls a thunk
# and wraps the result in an ERP. This seems convinient as existing
# function can be used to plot the results. This has different
# semantics to pmcmc(1,n,thunk) which simulates n executions of the
# program in which thunk is called once, rather than been a single
# execution of a program which calls the thunk n times.

# @pp
function Empirical(k::Function, comp::Function, n)
    repeat(comp, n) do samples
        counts = Dict{Any,Int64}()
        for s in samples
            counts[s] = get(counts,s,0) + 1
        end
        k(Empirical(counts))
    end
end

sample(erp::Empirical) = erp.xs[rand(erp.ps)]

# This is potentially misleading as we can't distinguish between an x
# that isn't in the support and one which has zero probability. Could
# the support be infered by looking at the distribution from which the
# sampled variables were originally drawn?

support(erp::Empirical) = keys(erp.counts)
score(erp::Empirical, x) = log(erp.counts[x]/erp.n)

function show(io::IO, erp::Empirical)
    print(io,"Empirical(")
    show(io,normalize(erp.counts))
    print(io,")")
end

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
uniform(k) = sample(k, StandardUniform())


immutable Normal <: ERP
    mean::Float64 # mu
    var::Float64  # sigma^2
    function Normal(mean, var)
        @assert var > 0.0
        new(mean,var)
    end
end

# @pp
Normal(k,mean,var) = k(Normal(mean,var))

sample(erp::Normal) = randn() * sqrt(erp.var) + erp.mean
# Un-normalized score.
score(erp::Normal, x) = (x-erp.mean)^2 / (-2. * erp.var)

# @pp
normal(k, mean, var) = sample(k, Normal(mean, var))


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
dirichlet(k::Function, alpha) = sample(k, Dirichlet(alpha))
dirichlet(k::Function, alpha, K) = sample(k, Dirichlet(alpha,K))


immutable Beta <: ERP
    alpha::Float64
    beta::Float64
    function Beta(alpha,beta)
        @assert alpha > 0.
        @assert beta > 0.
        new(alpha,beta)
    end
end

# @pp
Beta(k::Function,alpha,beta) = k(Beta(alpha,beta))

function sample(erp::Beta)
    x = randgamma(erp.alpha, 1.)
    y = randgamma(erp.beta, 1.)
    x / (x+y)
end

score(erp::Beta, x) = (erp.alpha-1.)*log(x) + (erp.beta-1.)*log(1.-x) - lbeta(erp.alpha,erp.beta)
support(erp::Beta) = error("not implemented")

# @pp
samplebeta(k::Function, alpha, beta) = sample(k, Beta(alpha, beta))

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
