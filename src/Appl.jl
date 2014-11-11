module Appl

using Base.Collections
using TinyCps

export @appl, sample, factor

# I think this condition could be used to conditionally include the
# plotting function.
# println(isdefined(Main, :Gadfly))

# TODO: Fix ugly hack.
# This is just a hack to save me modifying TinyCps to pass primitives
# around as a parameter.

push!(TinyCps.primatives, :println)
push!(TinyCps.primatives, :cons, :list, :head, :tail, :cat, :reverse)

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

using DataStructures: LinkedList, Nil, head, tail
export ==
==(x::LinkedList,y::LinkedList) = head(x) == head(y) && tail(x) == tail(y)
==(x::Nil,y::Nil) = true
==(x::Nil,y::LinkedList) = false # Might be redundent.
==(x::LinkedList,y::Nil) = false # Might be redundent.

end
