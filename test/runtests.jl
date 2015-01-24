using Stochy
import Stochy.support
using Base.Test

for f in ["inference", "erp", "cps", "store", "mem"]
    include("$(f)tests.jl")
end

println("Passed!")
