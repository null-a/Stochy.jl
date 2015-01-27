# This assumes that ps is normalized.
function rand(ps::Vector{Float64})
    acc = 0.
    r = rand()
    n = length(ps)
    for i in 1:n-1
        @inbounds acc += ps[i]
        isnan(acc) && error("unexpected nan in rand")
        r < acc && return i
    end
    n
end
