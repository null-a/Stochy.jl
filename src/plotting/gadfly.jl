module GadflySupport

using Stochy
import Stochy: ERP, support, recoversamples

export bar, density, histogram

gadflyloaded() = isdefined(Main, :Gadfly)
del(names...) = [Main.Gadfly.(n) for n in names]

function bar(erp::ERP)
    @assert gadflyloaded()
    plot, Geom, Scale, Theme, mm, Guide = del(:plot, :Geom, :Scale, :Theme, :mm, :Guide)
    xs = sort(collect(support(erp)))
    ys = map(x->exp(score(erp, x)), xs)
    plot(x=xs, y=ys, Geom.bar(), Scale.x_discrete, Theme(bar_spacing=2mm), Guide.ylabel("p(x)"))
end

function plotcontinuous(erp::Empirical, geometry, ylabel; range=())
    @assert gadflyloaded()
    plot, Guide, Scale = del(:plot, :Guide, :Scale)
    kwargs = Dict()
    range != () && (kwargs[:minvalue] = range[1]; kwargs[:maxvalue] = range[2])
    plot(x=recoversamples(erp), geometry, Scale.x_continuous(;kwargs...), Guide.ylabel(ylabel))
end

function density(erp::Empirical; range=())
    Geom, = del(:Geom)
    plotcontinuous(erp, Geom.density, "pdf(x)", range=range)
end

function histogram(erp::Empirical; bins=(), range=())
    Geom, = del(:Geom)
    kwargs = Dict()
    bins != () && (kwargs[:bincount] = bins)
    plotcontinuous(erp, Geom.histogram(;kwargs...), "count", range=range)
end

end # module
