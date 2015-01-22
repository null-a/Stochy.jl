module Stochy

using Base.Collections

export @pp, sample, factor, score, observe, mem

const primitives = [:+,:*,:-,:/,
                    :tuple, :mem, :println, :cons, :list, :tail, :cat,
                    :reverse, :.., :first, :second, :third, :fourth]

debugflag = false
debug(b::Bool) = global debugflag = b
debug() = debugflag

partial(f,arg) = (args...) -> f(arg,args...)

macro pp(expr)
    tx = storetransform(cps(desugar(expr), :(Stochy.store_exit)))
    debug() && println(striplineinfo(tx))
    esc(tx)
end

abstract Ctx
type Prior <: Ctx end
ctx = Prior()

include("cps.jl")
include("store.jl")
include("erp.jl")
include("rand.jl")
include("enumerate.jl")
include("pmcmc.jl")
include("dp.jl")
include("plotting/gadfly.jl")
include("plotting/pyplot.jl")

# Dispatch based on current context.
sample(s::Store, k::Function, e::ERP) = sample(s,k,e,ctx)
factor(s::Store, k::Function, score) = factor(s,k,score,ctx)

sample(s::Store, k::Function, e::ERP, ::Prior) = k(s,sample(e))

# @pp
score(s::Store, k::Function, e::ERP, x) = k(s,score(e,x))

observe(s::Store, k::Function, erp::ERP, x) = factor(s, k, score(erp,x))
observe(s::Store, k::Function, erp::ERP, xs...) = factor(s, k, sum([score(erp,x) for x in xs]))

# @pp
function mem(f::Function)
    key = gensym()
    (store::Store, k::Function, args...) -> begin
        cachekey = (key,args)
        if haskey(store,cachekey)
            k(store,store[cachekey])
        else
            partial(f,store)(args...) do s,val
                s = copy(s)
                s[cachekey] = val
                k(s,val)
            end
        end
    end
end

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
export .., first, second, third, fourth, repeat

using DataStructures: Cons, Nil, head, tail, cons, list

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

# TODO: Change the base case to n==1 so that the created list is
# tightly typed. Throw error for n<1.
@pp function repeat(f::Function, n::Int64)
    n < 1 ? list() : cons(f(), repeat(f, n-1))
end

end
