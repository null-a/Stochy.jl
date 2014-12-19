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
function sample(k::Function, e::ERP, ctx::Enum)
    for val in support(e)
        enq!(ctx.unexplored, (ctx.score + score(e, val), () -> k(val), [ctx.path, val]))
    end
    runnext()
end

# @pp
function factor(k::Function, score, ctx::Enum)
    ctx.score += score
    k(nothing)
end

function runnext()
    score, cont, path = deq!(ctx.unexplored)
    ctx.score = score
    ctx.path = path
    cont()
end

# @pp
enum(k::Function, comp::Function) = enumbreadthfirst(k, comp)

enumdepthfirst(k::Function, comp::Function) = enum(k, comp, Stack)
enumbreadthfirst(k::Function, comp::Function) = enum(k, comp, Queue)
enumlikelyfirst(k::Function, comp::Function) = enum(k, comp, PriorityQueue)

function enum(k::Function, comp::Function, queuetype::DataType)
    global ctx
    returns = Dict{Any,Float64}()
    ctxold, ctx = ctx, Enum(queuetype)
    try
        currentexec = 0
        trampoline() do
            comp() do value
                currentexec += 1
                returns[value] = get(returns, value, 0) + exp(ctx.score)
                if currentexec >= 1000
                    println("maximum executions reached")
                elseif !isempty(ctx.unexplored)
                    runnext()
                end
            end
        end
        normalize!(returns)
    finally
        ctx = ctxold
    end
    # Note: The context must be restored before calling k.
    k(Categorical(returns))
end
