using Stochy
import Stochy.support
using Base.Test

for f in ["inference", "erp", "cps", "store"]
    include("$(f)tests.jl")
end

println("Passed!")
