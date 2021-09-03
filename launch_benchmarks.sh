#!/bin/bash
source ./benchmark_utils.sh
date=$(date +%Y%m%d-%H%M%S)
(run_benchmarks gpu "coreneuron_gpu_mod2c coreneuron_gpu_nmodl" ${date} "none allmpi-nsys")
(run_benchmarks cpu "neuron coreneuron_cpu_mod2c coreneuron_cpu_nmodl coreneuron_cpu_ispc" ${date} "none")
