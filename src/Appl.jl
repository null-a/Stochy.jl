module Appl

using Base.Collections
using TinyCps

export @appl, sample, factor, score

# TODO: Fix ugly hack.
# This is just a hack to save me modifying TinyCps to pass primitives
# around as a parameter.

push!(TinyCps.primatives, :println)
push!(TinyCps.primatives, :cons, :list, :tail, :cat, :reverse, :.., :first, :second, :third, :fourth)

macro appl(expr)
    esc(cps(desugar(expr), identity))
end

abstract Ctx
type Prior <: Ctx end
ctx = Prior()

include("erp.jl")
include("enumerate.jl")
include("pmcmc.jl")
if isdefined(Main, :Gadfly)
    include("plot.jl")
else
    info("Load Gadfly before Appl to extend plot function.")
end

# Dispatch based on current context.
sample(e::ERP, k::Function) = sample(e,k,ctx)
factor(score, k::Function) = factor(score,k,ctx)

sample(e::ERP, k::Function, ::Prior) = k(sample(e))

# @appl
score(e::ERP, x, k::Function) = k(score(e,x))

function normalize!(dict)
    norm = sum(values(dict))
    for k in keys(dict)
        dict[k] /= norm
    end
end

function normalize(dict)
    ret = copy(dict)
    normalize!(ret)
    ret
end

import Base.==, Base.hash
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
