module Stochy

using Base.Collections

export @pp, sample, factor, score, observe

debugflag = false
debug(b::Bool) = global debugflag = b
debug() = debugflag

macro pp(expr)
    cpsexpr = cps(desugar(expr), :identity)
    debug() && println(striplineinfo(cpsexpr))
    esc(cpsexpr)
end

abstract Ctx
type Prior <: Ctx end
ctx = Prior()

include("cps.jl")
include("erp.jl")
include("rand.jl")
include("enumerate.jl")
include("pmcmc.jl")
if isdefined(Main, :Gadfly)
    include("plot.jl")
else
    info("Load Gadfly before Stochy to extend plot function.")
end

# Dispatch based on current context.
sample(k::Function, e::ERP) = sample(k,e,ctx)
factor(k::Function, score) = factor(k,score,ctx)

sample(k::Function, e::ERP, ::Prior) = k(sample(e))

# @pp
score(k::Function, e::ERP, x) = k(score(e,x))

observe(k::Function, erp::ERP, x) = factor(k, score(erp,x))
observe(k::Function, erp::ERP, xs...) = factor(k, sum([score(erp,x) for x in xs]))

function normalize!{_}(dict::Dict{_,Float64})
    norm = sum(values(dict))
    for k in keys(dict)
        dict[k] /= norm
    end
end

function normalize{K,V<:Number}(dict::Dict{K,V})
    ret = Dict{K,Float64}()
    norm = sum(values(dict))
    for k in keys(dict)
        ret[k] = dict[k]/norm
    end
    ret
end

import Base.==, Base.hash, Base.first
export .., first, second, third, fourth

using DataStructures: Cons, Nil, head, tail, cons

const .. = cons

==(x::Cons,y::Cons) = head(x) == head(y) && tail(x) == tail(y)
==(x::Nil,y::Cons) = false
==(x::Cons,y::Nil) = false
==(x::Nil,y::Nil) = true

hash(x::Cons,h::Uint64) = hash(tail(x), hash(head(x), h))

first(l::Cons)  = head(l)
second(l::Cons) = head(tail(l))
third(l::Cons)  = head(tail(tail(l)))
fourth(l::Cons) = head(tail(tail(tail(l))))

end
