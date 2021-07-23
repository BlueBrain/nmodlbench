#!/bin/bash
source ./benchmark_utils.sh
date=$(date +%Y%m%d-%H%M%S)
(run_benchmarks gpu "coreneuron_gpu_mod2c" ${date} "none allmpi-nsys")
(run_benchmarks cpu "coreneuron_cpu_mod2c" ${date} "none")
