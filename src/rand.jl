# This assumes that ps is normalized.
function rand(ps::Vector{Float64})
    acc = 0.
    r = rand()
    n = length(ps)
    for i in 1:n-1
        @inbounds acc += ps[i]
        isnan(acc) && nanerror()
        r < acc && return i
    end
    n == 1 && isnan(ps[1]) && nanerror()
    n
end

nanerror() = error("unexpected nan in rand")
