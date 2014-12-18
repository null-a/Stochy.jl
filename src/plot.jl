using Gadfly
import Gadfly.plot

# TODO: orientation=:horizontal?

function plot(erp::ERP)
    xs = sort(collect(support(erp)))
    ys = map(x->exp(score(erp, x)), xs)
    plot(x=xs, y=ys, Geom.bar, Scale.x_discrete)
end

# TODO: Add density histograms once available.
# https://github.com/dcjones/Gadfly.jl/issues/491

export density

function density(erp::Empirical)
    plot(x=recoversamples(erp), Geom.density)
end
