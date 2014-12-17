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
function sample(e::ERP, k::Function, ctx::Enum)
    for val in support(e)
        # TODO: A type for the thing we push on the queue might be nice.
        enq!(ctx.unexplored, (ctx.score + score(e, val), () -> k(val), [ctx.path, val]))
    end
    runnext()
end

# @pp
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

# @pp
enum(comp::Function, k::Function) = enumbreadthfirst(comp, k)

enumdepthfirst(comp::Function, k::Function) = enum(comp, Stack, k)
enumbreadthfirst(comp::Function, k::Function) = enum(comp, Queue, k)
enumlikelyfirst(comp::Function, k::Function) = enum(comp, PriorityQueue, k)

function enum(comp::Function, queuetype::DataType, k::Function)
    global ctx
    returns = Dict{Any,Float64}()
    ctxold, ctx = ctx, Enum(queuetype)
    try
        currentexec = 0
        trampoline() do
            comp() do value
                currentexec += 1
                returns[value] = get(returns, value, 0) + exp(ctx.score)
                # TODO: How best can this be presented?
                # It's useful/interesting to see when playing with
                # e.g. enumlikelyfirst() and re-ordering factor
                # statements etc.
                #println((ctx.path, exp(ctx.score)))
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
