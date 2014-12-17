using Gadfly
import Gadfly.plot

# TODO: orientation=:horizontal?

function plot(erp::ERP)
    xs = sort(collect(support(erp)))
    ys = map(x->exp(score(erp, x)), xs)
    plot(x=xs, y=ys, Geom.bar, Scale.x_discrete)
end
