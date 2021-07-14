#!/bin/bash
source ./benchmark_utils.sh
# Including coreneuron_gpu_mod2c here means "run a GPU-enabled build in CPU mode"
run_benchmarks cpu "coreneuron_cpu_mod2c coreneuron_gpu_mod2c" $(date +%Y%m%d-%H%M%S) "none"
