#!/bin/bash

#SBATCH --account=proj16
# SBATCH --partition=prod
#SBATCH --time=01:00:00

#SBATCH --nodes=1
#SBATCH --constraint=volta
#SBATCH --gres=gpu:4
#SBATCH --ntasks-per-node=36

#SBATCH --cpus-per-task=2
#SBATCH --exclusive
#SBATCH --mem=0

# Stop on error
#set -e

# =============================================================================
# SIMULATION PARAMETERS TO EDIT
# =============================================================================

# Using top level source and install directory, set the HOC_LIBRARY_PATH for simulator
root_dir="${PWD}"
output_prefix="${root_dir}/spack-outputs"
BASE_DIR=$(pwd)/benchmark
INSTALL_DIR=$BASE_DIR/install
SOURCE_DIR=$BASE_DIR/sources

export HOC_LIBRARY_PATH=$BASE_DIR/channels/lib/hoclib

#Change this according to the desired runtime of the benchmark
export SIM_TIME=1

# Number of cells ((LCM of #cores_system1, #core_system2)*#cell_types)
export NUM_CELLS=$((360*22))
#export NUM_CELLS=44

# =============================================================================

# Enter the channel benchmark directory
cd $BASE_DIR/channels

#rm -rf coredat_gpu
#rm NRN_GPU.spk GPU_MOD2C.spk GPU_NMODL.spk
#rm NRN_GPU.log GPU_MOD2C.log GPU_NMODL.log

# Load external packages that only work because of $LD_LIBRARY_PATH
module load unstable hpe-mpi

# Load Spack after the above modules, so we don't pick up modules from our private Spack installation.
. ~/bin/setup_spack_env.sh

# Load tools that we want to explicitly use (nsys)
#module load cuda/11.3.1
module list

num_mpi=36
neuron_spikes="${output_prefix}/neuron/NRN.spk"
if [[ -f "${neuron_spikes}" ]]
then
  echo "Skipping creating ${neuron_spikes}"
else
  echo "----------------- NEURON SIM (CPU) ----------------"
  (
    spack env activate ${root_dir}/spack-envs/neuron
    mkdir -p "${output_prefix}/neuron"
    srun -n ${num_mpi} dplace ${root_dir}/spack-specials/neuron/x86_64/special -mpi -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc |& tee "${output_prefix}/neuron/NRN.log"
    sort -k 1n,1n -k 2n,2n > "${neuron_spikes}" < out.dat
    rm out.dat
  )
fi

coreneuron_input="${output_prefix}/coreneuron/coredat"
if [[ -d "${coreneuron_input}" ]]
then
  echo "Skipping producing ${coreneuron_input}"
else
  echo "----------------- Produce coredat ----------------"
  (
    spack env activate ${root_dir}/spack-envs/neuron
    mkdir -p "${output_prefix}/coreneuron"
    srun -n ${num_mpi} dplace ${root_dir}/spack-specials/neuron/x86_64/special -mpi -c arg_dump_coreneuron_model=1 -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc |& tee "${output_prefix}/coreneuron/NRN.log"
    mv coredat/ "${coreneuron_input}"
  )
fi

# =============================================================================
nvidia-cuda-mps-control -d # Start the daemon

echo "----------------- CoreNEURON SIM (GPU_MOD2C) ----------------"
#export CALI_CONFIG=nvtx #,runtime-report
export CALI_CONFIG=nvtx,runtime-report,profile.mpi
#CALI_CONFIG=runtime-report,profile.cuda,profile.mpi srun -n ${num_mpi} /gpfs/bbp.cscs.ch/home/olupton/channel-benchmark/spack-specials/coreneuron_gpu_mod2c/x86_64/special-core -e 10 --gpu -d ${root_dir}/spack-src-dirs/coreneuron/tests/integration/ring --mpi
(
  spack env activate "${root_dir}/spack-envs/coreneuron_gpu_mod2c"
  mkdir -p "${output_prefix}/coreneuron_gpu_mod2c"
  command -v nsys
  command -v mpirun
  export NSYS_NVTX_PROFILER_REGISTER_ONLY=0
  srun -n ${num_mpi} sh ${root_dir}/launch_nsys.sh "${root_dir}/spack-profiles/$(date +%Y%m%d-%H%M%S)-%q{SLURM_PROCID}" \
    dplace "${root_dir}/spack-specials/coreneuron_gpu_mod2c/x86_64/special-core" \
    --voltage 1000. --mpi --gpu --cell-permute 2 --tstop $SIM_TIME -d "${coreneuron_input}" |& tee "${output_prefix}/coreneuron_gpu_mod2c/CNRN.log"
  sort -k 1n,1n -k 2n,2n > "${output_prefix}/coreneuron_gpu_mod2c/CNRN.spk" < out.dat
  rm out.dat
)
# Cleanup temporary files
find /tmp/nvidia/nsight_systems -mindepth 1 -maxdepth 1 -user ${USER} -type d -print0 | xargs -0 rm -rf

#echo "----------------- CoreNEURON SIM (GPU_NMODL) ----------------"
#srun dplace $INSTALL_DIR/GPU_NMODL/special/x86_64/special-core --mpi --voltage 1000. --gpu --cell-permute 2 --tstop $SIM_TIME -d coredat_gpu 2>&1 | tee GPU_NMODL.log
## Sort the spikes
#cat out.dat | sort -k 1n,1n -k 2n,2n > GPU_NMODL.spk
#rm out.dat

echo quit | nvidia-cuda-mps-control
# =============================================================================

echo "---------------------------------------------"
echo "-------------- Compare Spikes ---------------"
echo "---------------------------------------------"

DIFF=$(diff NRN_GPU.spk GPU_MOD2C.spk)
if [ "$DIFF" != "" ] 
then
    echo "NRN_GPU.spk GPU_MOD2C.spk are not the same"
else
    echo "NRN_GPU.spk GPU_MOD2C.spk are the same"
fi

#DIFF=$(diff NRN_GPU.spk GPU_NMODL.spk)
#if [ "$DIFF" != "" ] 
#then
#    echo "NRN_GPU.spk GPU_NMODL.spk are not the same"
#else
#    echo "NRN_GPU.spk GPU_NMODL.spk are the same"
#fi

# =============================================================================

echo "---------------------------------------------"
echo "----------------- SIM STATS -----------------"
echo "---------------------------------------------"

echo "Number of cells: $NUM_CELLS"
echo "----------------- NEURON SIM STATS (CPU) ----------------"
grep "psolve" NRN_GPU.log
echo "----------------- CoreNEURON SIM (GPU_MOD2C) STATS ----------------"
grep "Solver Time" GPU_MOD2C.log
#echo "----------------- CoreNEURON SIM (GPU_NMODL) STATS ----------------"
#grep "Solver Time" GPU_NMODL.log

echo "---------------------------------------------"
echo "---------------------------------------------"
