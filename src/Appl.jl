module Appl

using Base.Collections
using TinyCps

export @appl, sample, factor

# TODO: Fix ugly hack.
# This is just a hack to save me modifying TinyCps to pass primitives
# around as a parameter.

push!(TinyCps.primatives, :println)
push!(TinyCps.primatives, :cons, :list, :tail, :cat, :reverse, :.., :first, :second, :third, :fourth)

macro appl(expr)
    expr = esc(cps(desugar(expr), :(Base.identity)))
    println(expr)
    #Meta.show_sexpr(expr)
    expr
end

abstract Ctx
type Prior <: Ctx end
ctx = Prior()

include("erp.jl")
include("enumerate.jl")
if isdefined(Main, :Gadfly)
    include("plot.jl")
else
    info("Load Gadfly before Appl to extend plot function.")
end

# Dispatch based on current context.
sample(e::ERP, k::Function) = sample(e,k,ctx)
factor(score, k::Function) = factor(score,k,ctx)

sample(e::ERP, k::Function, ::Prior) = k(sample(e))

function normalize!(dict)
    norm = sum(values(dict))
    for k in keys(dict)
        dict[k] /= norm
    end
end

import Base.==
export .., first, second, third, fourth

using DataStructures: Cons, Nil, head, tail, cons

const .. = cons

==(x::Cons,y::Cons) = head(x) == head(y) && tail(x) == tail(y)
==(x::Nil,y::Cons) = false
==(x::Cons,y::Nil) = false
==(x::Nil,y::Nil) = true

first(l::Cons)  = head(l)
second(l::Cons) = head(tail(l))
third(l::Cons)  = head(tail(tail(l)))
fourth(l::Cons) = head(tail(tail(tail(l))))

end
