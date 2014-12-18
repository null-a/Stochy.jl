using Gadfly
import Gadfly.plot

function plot(erp::ERP)
    xs = sort(collect(support(erp)))
    ys = map(x->exp(score(erp, x)), xs)
    plot(x=xs, y=ys, Geom.bar, Scale.x_discrete)
end

export density

function density(erp::Empirical)
    plot(x=recoversamples(erp), Geom.density)
end
