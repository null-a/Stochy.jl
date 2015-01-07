using Stochy
import Stochy.support
using Base.Test

for f in ["inference", "erp", "cps", "cc"]
    include("$(f)tests.jl")
end

println("Passed!")
