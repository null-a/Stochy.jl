# Stochy.jl

Stochy is a probabilistic programming language embedded within Julia. Models are specified using a functional subset of Julia, and inference can be performed by either exhaustive enumeration or PMCMC<sup>[1](#citations)</sup>. The implementation follows the approach described in [The Design and Implementation of Probabilistic Programming Languages](http://dippl.org/).

## Status

Stochy is in its infancy and you almost certainly want to use the most
recent version. This can be installed from the Julia REPL like so:

```
Pkg.add("Stochy")
Pkg.checkout("Stochy")
```

## Examples

- [Introduction](http://nbviewer.ipython.org/github/null-a/StochyExamples/blob/master/Introduction.ipynb)
- [Bayes Net](http://nbviewer.ipython.org/github/null-a/StochyExamples/blob/master/Bayes%20Net.ipynb)
- [Marbles](http://nbviewer.ipython.org/github/null-a/StochyExamples/blob/master/Marbles.ipynb)
- [Dirichlet Process Mixture Model](http://nbviewer.ipython.org/github/null-a/StochyExamples/blob/master/Dirichlet%20Process%20Mixture%20Model.ipynb)

## Citations

1. Wood, F., J. W. van de Meent, and V. Mansinghka. 2014. “A New Approach to Probabilistic Programming Inference.” In Artificial Intelligence and Statistics, 1024–32.
