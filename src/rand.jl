import Base.Random.rand

function rand(ps::Vector{Float64})
    @assert isdistribution(ps)
    acc = 0.
    r = rand()
    for (i,p) in enumerate(ps)
        acc += p
        if r < acc
            return i
        end
    end
    error("unreachable")
end

# Implementation based on "A Simple Method for Generating Gamma
# Variables" by George Marsaglia and Wai Wan Tsang. ACM Transactions
# on Mathematical Software Vol 26, No 3, September 2000, pages
# 363-372.

# See http://www.johndcook.com/julia_rng.html and Numerical Recipes
# Third Edition.

function randgamma(shape::Float64, scale::Float64)
    shape <= 0. && error("shape parameter (k) must be positive")
    scale <= 0. && error("scale parameter (theta) must be positive")
    if shape >= 1.
        d = shape - 1./3.
        c = 1. / sqrt(9.*d)
        while true
            x = randn()
            v = 1. + c*x
            while v <= 0.
                x = randn()
                v = 1. + c*x
            end
            v = v*v*v
            u = rand()
            xsq = x*x
            if u < 1. - .0331*xsq*xsq || log(u) < .5*xsq + d*(1. - v + log(v))
                return scale * d * v
            end
        end
    else
        g = randgamma(shape + 1., 1.)
        w = rand()
        scale * g * w^(1./shape)
    end
end
