module GadflySupport

using Stochy
import Stochy: ERP, support

export bar, density, histogram

gadflyloaded() = isdefined(Main, :Gadfly)
del(names...) = [Main.Gadfly.(n) for n in names]

function samples(erp::Discrete)
    @assert isa(erp.dict, Dict{Any,Int64})
    n = sum(values(erp.dict))
    ret = Array(Any, n)
    i = 1
    for (x,c) in erp.dict
        for _ in 1:c
            ret[i] = x
            i += 1
        end
    end
    ret
end

function bar(erp::ERP)
    @assert gadflyloaded()
    plot, Geom, Scale, Theme, mm, Guide = del(:plot, :Geom, :Scale, :Theme, :mm, :Guide)
    xs = sort(collect(support(erp)))
    ys = map(x->exp(score(erp, x)), xs)
    plot(x=xs, y=ys, Geom.bar(), Scale.x_discrete, Theme(bar_spacing=2mm), Guide.ylabel("p(x)"), Scale.y_continuous(minvalue=0, maxvalue=1))
end

function plotcontinuous(erp::Discrete, geometry, ylabel)
    @assert gadflyloaded()
    plot, Guide, Scale = del(:plot, :Guide, :Scale)
    plot(x=samples(erp), geometry, Scale.y_continuous(scalable=false), Guide.ylabel(ylabel))
end

function density(erp::Discrete)
    Geom, = del(:Geom)
    plotcontinuous(erp, Geom.density, "pdf(x)")
end

function histogram(erp::Discrete; bins=nothing)
    Geom, = del(:Geom)
    kwargs = Dict()
    bins != nothing && (kwargs[:bincount] = bins)
    plotcontinuous(erp, Geom.histogram(;kwargs...), "count")
end

end # module
