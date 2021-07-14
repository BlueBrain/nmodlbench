#!/bin/bash
source ./benchmark_utils.sh
run_benchmarks gpu "coreneuron_cpu_mod2c coreneuron_gpu_mod2c coreneuron_gpu_mod2c_cuda110" $(date +%Y%m%d-%H%M%S) "none allmpi-nsys"

