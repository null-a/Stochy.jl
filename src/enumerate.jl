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
    Enum(queuetype) = new(0, Any[], queuetype())
end

# @pp
function sample(s::Store, k::Function, a, e::ERP, ctx::Enum)
    for val in support(e)
        enq!(ctx.unexplored, (ctx.score + score(e, val), () -> k(s,val), [ctx.path, val]))
    end
    runnext(ctx)
end

# @pp
function factor(s::Store, k::Function, a, score, ctx::Enum)
    ctx.score += score
    k(s, nothing)
end

function runnext(ctx::Ctx)
    score, cont, path = deq!(ctx.unexplored)
    ctx.score = score
    ctx.path = path
    cont()
end

# @pp
enum(s::Store, k::Function, a, comp::Function, maximumexec::Int64=0) = enumbreadthfirst(s, k, a, comp, maximumexec)

enumdepthfirst(s::Store, k::Function, a, comp::Function, maximumexec::Int64=0) = enum(s, k, a, comp, Stack, maximumexec)
enumbreadthfirst(s::Store, k::Function, a, comp::Function, maximumexec::Int64=0) = enum(s, k, a, comp, Queue, maximumexec)
enumlikelyfirst(s::Store, k::Function, a, comp::Function, maximumexec::Int64=0) = enum(s, k, a, comp, PriorityQueue, maximumexec)

function enum(store::Store, k::Function, address, comp::Function, queuetype::DataType, maximumexec::Int64=0)
    global ctx
    returns = Dict{Any,Float64}()
    ctxold, ctx = ctx, Enum(queuetype)
    try
        currentexec = 0
        trampoline() do
            partial(comp,store)(address) do _store, value
                currentexec += 1
                returns[value] = get(returns, value, 0) + exp(ctx.score)
                if maximumexec > 0 && currentexec == maximumexec
                    info("Maximum executions reached.")
                elseif !isempty(ctx.unexplored)
                    runnext(ctx)
                end
            end
        end
    finally
        ctx = ctxold
    end
    # Note: The context must be restored before calling k.
    k(store, Discrete(returns))
end
