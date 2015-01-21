module PyPlotSupport

using Stochy
import Stochy: ERP, support

export histogram, bar

pyplotloaded() = isdefined(Main, :PyPlot)
del(names...) = [Main.PyPlot.(n) for n in names]

function bar(erp::ERP; kwargs...)
    @assert pyplotloaded()
    pybar, xticks, xlim, figure, xlabel, ylabel = del(:bar, :xticks, :xlim, :figure, :xlabel, :ylabel)
    xs = sort(collect(support(erp)))
    ps = map(x->exp(score(erp,x)), xs)
    N = length(xs)
    spacing = 0.05
    width = 1 - 2*spacing
    figure(figsize=(6,4))
    pybar([1:N]+spacing, ps, width; kwargs...)
    xticks([1:N]+0.5, xs)
    xlim(1,N+1)
    xlabel("x")
    ylabel("p(x)")
end

function histogram(erp::Empirical; kwargs...)
    @assert pyplotloaded()
    hist, figure, xlabel, ylabel = del(:hist, :figure, :xlabel, :ylabel)
    figure(figsize=(6,4))
    hist(;x=erp.xs, weights=erp.ps, kwargs...)
    xlabel("x")
    ylabel("count")
end

end # module
