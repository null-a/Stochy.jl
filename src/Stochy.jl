module Stochy

using Base.Collections
import Base: factor, show

import Distributions
import Distributions: Distribution, support, rand, params
const score = Distributions.logpdf

export @pp, sample, factor, score, observe, mem, cache
export Discrete, Dir, flip, randominteger, hellingerdistance, kl

const primitives = [:!,:+,:*,:-,:/,:sqrt,:√,
                    :tuple, :mem, :println, :cons, :list, :tail, :cat,
                    :reverse, :.., :first, :second, :third, :fourth]

debugflag = false
debug(b::Bool) = global debugflag = b
debug() = debugflag

partial(f,arg) = (args...) -> f(arg,args...)

macro pp(expr)
    tx = storetransform(cps(addressing(desugar(expr)), :(Stochy.store_exit)))
    debug() && println(striplineinfo(tx))
    esc(tx)
end

abstract Ctx
type Prior <: Ctx end
ctx = Prior()

include("cps.jl")
include("store.jl")
include("addressing.jl")
include("erp.jl")
include("rand.jl")
include("enumerate.jl")
include("mh.jl")
include("pmcmc.jl")
include("variational.jl")
include("dp.jl")
include("plotting/gadfly.jl")
include("plotting/pyplot.jl")

# Dispatch based on current context.
sample(s::Store, k::Function, a, e::ERP) = sample(s,k,a,e,ctx)
factor(s::Store, k::Function, a, score) = factor(s,k,a,score,ctx)

sample(s::Store, k::Function, a, e::ERP, ::Prior) = k(s,rand(e))

# @pp
score(s::Store, k::Function, a, e::ERP, x) = k(s,score(e,x))

observe(s::Store, k::Function, a, erp::ERP, x) = factor(s, k, a, score(erp,x))
observe(s::Store, k::Function, a, erp::ERP, xs...) = factor(s, k, a, sum([score(erp,x) for x in xs]))


# cache and mem are similar. The primary difference is that mem uses a
# cache local to the "thread", cache uses a global cache. Another
# difference is that the cache used by mem is local to a @pp block,
# whereas the cache shares its cache between @pp blocks.

# @pp
function mem(f::Function)
    key = gensym()
    (store::Store, k::Function, address, args...) -> begin
        cachekey = (key,args)
        if haskey(store,cachekey)
            k(store,store[cachekey])
        else
            partial(f,store)(address, args...) do s,val
                s = copy(s)
                s[cachekey] = val
                k(s,val)
            end
        end
    end
end

const CACHE = Dict()

# @pp
function cache(s::Store, k::Function, address, f::Function)
    partial(k,s)() do s2, k2, a2, args...
        # This is the body of the memoized function.
        if haskey(CACHE, args)
            k2(s2, CACHE[args])
        else
            partial(f,s2)(a2, args...) do s3, value
                CACHE[args] = value
                k2(s3,value)
            end
        end
    end
end

import Base.==, Base.hash, Base.first, Base.isless
export .., first, second, third, fourth, repeat

using DataStructures: Cons, Nil, head, tail, cons, list, cat
export cons, list

const .. = cons

==(x::Cons,y::Cons) = head(x) == head(y) && tail(x) == tail(y)
==(x::Nil,y::Cons) = false
==(x::Cons,y::Nil) = false
==(x::Nil,y::Nil) = true

hash(x::Cons,h::Uint64) = hash(tail(x), hash(head(x), h))
hash(_::Nil,h::Uint64) = hash(object_id(list()), h)

function isless(xs::Cons,ys::Cons)
    x, y = head(xs), head(ys)
    x==y ? isless(tail(xs), tail(ys)) : isless(x,y)
end

isless(xs::Nil,ys::Cons) = true
isless(xs::Cons,ys::Nil) = false
isless(xs::Nil,ys::Nil) = true

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
