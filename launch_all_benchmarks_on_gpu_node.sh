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
# 4xV100 32GB PCIe GPUs. No NVLINK. Same CPU model as the bulk of the phase 2
# CPU nodes (but 2x more memory).
source ./benchmark_utils.sh
gpu_builds="coreneuron_gpu_mod2c coreneuron_gpu_nmodl coreneuron_gpu_nmodl_sympy"
# GPU+NMODL does not work on CPU: https://github.com/BlueBrain/nmodl/issues/727
cpu_builds="coreneuron_cpu_mod2c coreneuron_gpu_mod2c coreneuron_cpu_ispc coreneuron_cpu_nmodl coreneuron_cpu_nmodl_sympy"
date=$(date +%Y%m%d-%H%M%S)
# 1 rank/core, no GPUs
(run_benchmarks cpu ${SLURM_TASKS_PER_NODE} 0 "${cpu_builds}" "${date}" "none")
# 1 rank/core, 1 GPU
(run_benchmarks gpu ${SLURM_TASKS_PER_NODE} 1 "${gpu_builds}" "${date}" "none")
# 1 rank/core, 4 GPUs
(run_benchmarks gpu ${SLURM_TASKS_PER_NODE} 4 "${gpu_builds}" "${date}" "none")
# 1 rank/GPU, 4 GPUs
(run_benchmarks gpu 4 4 "${gpu_builds}" "${date}" "none")
# 4 ranks, 1 GPU
(run_benchmarks gpu 4 1 "${gpu_builds}" "${date}" "none")
