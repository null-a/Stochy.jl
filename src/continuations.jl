import Base: reset
export shift, callcc

# @pp
callcc(s::Store, k::Function, f::Function) = f(s,k,(s,_,x) -> k(s,x))

# Simulate delimited continuations using call/cc.
# Taken from: http://mumble.net/~campbell/scheme/shift-reset.scm

# TODO: Implement reset/shift directly as primitives rather than via
# call/cc.

metacontinuation = @pp value -> error("No top-level reset.")

# @pp
function setmeta!(s::Store,k::Function,value)
    global metacontinuation
    metacontinuation = value
    k(s,nothing)
end

@pp function reset(thunk)
    local mc = metacontinuation
    callcc() do k
        setmeta!(value -> begin
            setmeta!(mc)
            k(value)
        end)
        local result = thunk()
        metacontinuation(result)
    end
end

# @pp function shift(f)
#     callcc() do k
#         local result = f(value -> reset(() -> k(value)))
#         metacontinuation(result)
#     end
# end

@pp function shift(f)
    # Capture the store along with the continuation. I suspect this
    # will always be the desired behaviour when exploring multiple
    # executions of a probabilistic program.
    local s = getcurstore()
    callcc() do k
        local result = f() do value
            reset() do
                setcurstore!(s)
                k(value)
            end
        end
        metacontinuation(result)
    end
end

getcurstore(s::Store, k::Function) = k(s,s)
# Discard the current store, use s instead.
setcurstore!(_::Store, k::Function, s::Store) = k(s,nothing)



# Additional helps for inference algoriths written in Stochy.
# TODO: Write these in Stochy.


# @pp
function incontext(s::Store, k::Function, f::Function, context::Ctx)
    # NOTE: This doesn't restore the context when an exception occurs.
    # Perhaps that should happen in one place higher up the stack,
    # perhaps in @pp?
    global ctx
    ctxold, ctx = ctx, context
    partial(f,s)() do s2, val
        ctx = ctxold
        # TODO: Consider continuing with s2 rather than s.

        # I think I effectively already do so in enum.

        # s2 may contain modifications to the store made during
        # inference. Exactly what modifications are present at the end
        # of inference may depend on details of the inference
        # procedure. e.g. search strategy in enumeration. This doesn't
        # seem to be the right thing to do. Further, caching the
        # results of enumeration may be problematic if the store is
        # modified during inference, as performing inference is no
        # longer equivalent to returning a cached ERP. (Returning the
        # cached ERP won't modify the store.)
        k(s2,val)
    end
end

# get and setindex! are added as primitives.
import Base.Dict
Dict(s::Store,k::Function) = k(s,Dict())

# @pp
function getstore(s::Store, k::Function, var::Symbol)
    # Special handling of score to avoid handling it not been set at
    # the first level of inference. (Which would be clunk in Stochy at
    # present.) Perhaps this should be set when the store is created.
    # (Assuming it remains in the store and doesn't move into the
    # context.)
    if var == :score
        k(s, get(s,var,0.))
    else
        k(s, s[var])
    end
end

# @pp
function setstore!(s::Store, k::Function, var::Symbol, val)
    # Copy-on-write.
    s = copy(s)
    s[var] = val
    k(s, nothing)
end
