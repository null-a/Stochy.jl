# Stochy.jl

Stochy is a probabilistic programming language embedded within Julia. Models are specified using a functional subset of Julia, and inference can be performed by either exhaustive enumeration or PMCMC<sup>[1](#citations)</sup>. The implementation follows the approach described in [The Design and Implementation of Probabilistic Programming Languages](http://dippl.org/).

## Examples

- [Introduction](http://nbviewer.ipython.org/github/null-a/StochyExamples/blob/master/Introduction.ipynb)
- [Marbles](http://nbviewer.ipython.org/github/null-a/StochyExamples/blob/master/Marbles.ipynb)

## Dependencies

[CPS.jl](https://github.com/null-a/CPS.jl) needs to be installed manually until Stochy.jl is registered as a package.

## Citations

1. Wood, F., J. W. van de Meent, and V. Mansinghka. 2014. “A New Approach to Probabilistic Programming Inference.” In Artificial Intelligence and Statistics, 1024–32.
