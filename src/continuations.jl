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
