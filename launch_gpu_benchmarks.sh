#!/bin/bash
source ./benchmark_utils.sh
builds="coreneuron_cpu_mod2c coreneuron_cpu_mod2c_nvhpc coreneuron_cpu_mod2c_nvhpc_debug coreneuron_gpu_mod2c coreneuron_gpu_mod2c_debug"
builds="coreneuron_cpu_mod2c coreneuron_gpu_mod2c"
(run_benchmarks gpu "${builds}" $(date +%Y%m%d-%H%M%S) "none")
compare_results gpu "${builds}"
