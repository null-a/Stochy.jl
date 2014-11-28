import Base.isempty
export enum, enumbreadthfirst, enumdepthfirst, enumlikelyfirst

type Stack
    store
    Stack() = new(Any[])
end

# I doubt enq!/deq! will run in constant time for this. Perhaps look
# at DataStructures.jl.
type Queue
    store
    Queue() = new(Any[])
end

# Provide a minimal common interface over Stack, Queue, PriorityQueue.

enq!(a::Union(Stack,Queue), item) = push!(a.store, item)

deq!(a::Stack) = pop!(a.store)
deq!(a::Queue) = shift!(a.store)

isempty(a::Union(Stack,Queue)) = isempty(a.store)

enq!(q::PriorityQueue, item) = enqueue!(q, item, -item[1])
deq!(q::PriorityQueue) = dequeue!(q)

type Enum <: Ctx
    score::Float64
    path
    unexplored
    returns
    Enum(frontier) = new(0, Any[], frontier, Dict{Any,Float64}())
end

# @appl
function sample(e::ERP, k::Function, ctx::Enum)
    for val in support(e)
        # TODO: A type for the thing we push on the queue might be nice.
        enq!(ctx.unexplored, (ctx.score + score(e, val), () -> k(val), [ctx.path, val]))
    end
    runnext()
end

# @appl
function factor(score, k::Function, ctx::Enum)
    ctx.score += score
    k(nothing)
end

function runnext()
    score, cont, path = deq!(ctx.unexplored)
    ctx.score = score
    ctx.path = path
    cont()
end

# @appl
enum(comp::Function, k::Function) = enumbreadthfirst(comp, k)

enumdepthfirst(comp::Function, k::Function) = enum(comp, Stack, k)
enumbreadthfirst(comp::Function, k::Function) = enum(comp, Queue, k)
enumlikelyfirst(comp::Function, k::Function) = enum(comp, PriorityQueue, k)

function enum(comp::Function, frontiertype::DataType, k::Function)
    global ctx
    local ctxfin
    ctxold, ctx = ctx, Enum(frontiertype())
    try
        currentexec = 0
        comp() do val 
            currentexec += 1
            if !haskey(ctx.returns, val)
                ctx.returns[val] = 0
            end
            ctx.returns[val] += exp(ctx.score)
            println((ctx.path, exp(ctx.score)))
            if currentexec >= 1000
                println("maximum executions reached")
            elseif !isempty(ctx.unexplored)
                runnext()
            end
        end
        normalize!(ctx.returns)
    finally
        ctx, ctxfin = ctxold, ctx
    end
    Discrete(ctxfin.returns, k)
end
