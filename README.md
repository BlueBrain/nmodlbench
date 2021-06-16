# Channel Benchmark

## Installation

The ```instal.sh``` script builds the following under the ```benchmark/install``` folder:

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

The output of the tests is stored in ```benchmark/channels``` folder (```BUILD_TYPE.dat / BUILD_TYPE.log``` files).
