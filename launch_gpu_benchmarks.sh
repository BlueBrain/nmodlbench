#!/bin/bash
#SBATCH --account=proj16
#SBATCH --partition=prod_p2
#SBATCH --time=8:00:00
#SBATCH --nodes=1
#SBATCH --constraint=volta,v100
#SBATCH --exclude=ldir01u01,ldir01u13
#SBATCH --gres=gpu:4
#SBATCH --ntasks-per-node=40
#SBATCH --cpus-per-task=2
#SBATCH --exclusive
#SBATCH --mem=0
# Constraints are designed to get phase 2 GPU nodes w/ Intel Xeon 6248 CPUs and
# 4xV100 32GB PCIe GPUs. No NVLINK.
source ./benchmark_utils.sh
builds="coreneuron_gpu_mod2c coreneuron_gpu_nmodl coreneuron_gpu_nmodl_sympy"
(run_benchmarks gpu "${builds}" $(date +%Y%m%d-%H%M%S) "none")
compare_results gpu "${builds}"
