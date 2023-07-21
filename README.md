# NMODL Benchmark

This repository is created to publish channel benchmark used for comparing performance of
[NMODL Framework](https://github.com/BlueBrain/nmodl) as part of the manuscript arXiv:submit/2678839. This repository will provide :
* Collection of cells with different m-e types (including MOD files)
* Build scripts for
  * NEURON + nocmodl
  * CoreNEURON + mod2c
  * CoreNEURON + NMODL
* Benchmarking scripts based on [Caliper](https://github.com/LLNL/Caliper)
* Jupyter notebook for post-processing Caliper data and plotting
* Docker container

For more information, see this issue : [BlueBrain/nmodl/issues/193](https://github.com/BlueBrain/nmodl/issues/193)

## Compatibility

- This version of the repository is compatible with NEURON versions newer than 8.1 (!9)

## Installation

The ```install.sh``` script builds the following under the ```benchmark/install``` folder:

1. Neuron (for building network model).
2. NMODL (used for translating DSL to C++ code).
3. CoreNEURON for CPUs (intel compiler) with MOD2C (used for translating DSL to C++ code).
4. CoreNEURON for CPUs (intel compiler) with NMODL.
5. CoreNEURON for GPUs with MOD2C.
6. CoreNEURON for GPUs with NMODL.
7. CoreNEURON for CPUs (ISPC) with NMODL.

After the buidling phase, it follows the creation of the **special** & **special-core** under the ```benchmark/install/BUILD_TYPE/x86_64/``` folders.

## Run Simulations

The ```run_cpu.sh``` & ```run_gpu.sh``` scripts launch the tests:
* ```sbatch run_cpu.sh``` (CPU-only tests)
* ```sbatch run_gpu.sh``` (GPU-only tests)

The output of the tests is stored in ```benchmark/channels``` folder (```BUILD_TYPE.spk / BUILD_TYPE.log``` files).



## Funding & Acknowledgment

The development of this software was supported by funding to the Blue Brain Project, a research center of the École polytechnique fédérale de Lausanne (EPFL), from the Swiss government's ETH Board of the Swiss Federal Institutes of Technology.

Copyright © 2019-2022 Blue Brain Project/EPFL
