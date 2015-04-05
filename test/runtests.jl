using Stochy
import Stochy.support
using Base.Test

for f in ["inference", "variational", "erp", "cps", "store", "addressing", "mem", "rand"]
    include("$(f)tests.jl")
end

println("Passed!")
