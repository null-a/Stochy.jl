using Gadfly
import Gadfly.plot

# TODO: orientation=:horizontal?
# TODO: Drop zero prob events by default?
# TODO: Test this works for ERP other than discrete.

function plot(erp::ERP)
    xs = sort(support(erp))
    ys = map(x->exp(score(erp, x)), xs)
    plot(x=xs, y=ys, Geom.bar, Scale.x_discrete)
end
