#!/bin/bash
#SBATCH --account=proj16
#SBATCH --partition=prod_p2
#SBATCH --time=8:00:00
#SBATCH --nodes=1
#SBATCH --constraint='cpu&clx'
#SBATCH --ntasks-per-node=40
#SBATCH --cpus-per-task=2
#SBATCH --exclusive
#SBATCH --mem=0
source ./benchmark_utils.sh
# Including coreneuron_gpu_mod2c here means "run a GPU-enabled build in CPU mode"
# coreneuron_gpu_nmodl and coreneuron_gpu_nmodl_sympy did not work
run_benchmarks cpu "coreneuron_cpu_mod2c coreneuron_gpu_mod2c coreneuron_cpu_ispc coreneuron_cpu_nmodl coreneuron_cpu_nmodl_sympy" $(date +%Y%m%d-%H%M%S) "none" # allmpi-nsys"
