using Stochy
#Stochy.debug(true)

# When the store isn't correctly copied during inference, each of
# these strategies returns a different distribution.

@pp function model()
    local g = mem(_->flip(0.7))
    flip(0.6)
    g(0)
end

println(@pp enum(model))
println(@pp enumdepthfirst(model))
println(@pp enumlikelyfirst(model))
