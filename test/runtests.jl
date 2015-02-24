using Stochy
import Stochy.support
using Base.Test
using DataStructures

for f in ["inference", "erp", "cps", "store", "mem", "continuations"]
    include("$(f)tests.jl")
end

println("Passed!")
