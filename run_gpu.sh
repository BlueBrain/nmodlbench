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
BASE_DIR=$(pwd)/benchmark
INSTALL_DIR=$BASE_DIR/install
SOURCE_DIR=$BASE_DIR/sources

export HOC_LIBRARY_PATH=$BASE_DIR/channels/lib/hoclib
. $SOURCE_DIR/venv/bin/activate
export PYTHONPATH=$INSTALL_DIR/NRN/lib/python:$PYTHONPATH

#Change this according to the desired runtime of the benchmark
export SIM_TIME=10

# Number of cells ((LCM of #cores_system1, #core_system2)*#cell_types)
export NUM_CELLS=$((360*22))

# =============================================================================

# Enter the channel benchmark directory
cd $BASE_DIR/channels

rm -rf coredat_gpu
rm NRN_GPU.spk GPU_MOD2C.spk GPU_NMODL.spk
rm NRN_GPU.log GPU_MOD2C.log GPU_NMODL.log

echo "----------------- NEURON SIM (CPU) ----------------"
srun dplace $INSTALL_DIR/NRN/special/x86_64/special -mpi -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc 2>&1 | tee NRN_GPU.log
# Sort the spikes
cat out.dat | sort -k 1n,1n -k 2n,2n > NRN_GPU.spk
rm out.dat

echo "----------------- Produce coredat ----------------"
srun dplace $INSTALL_DIR/NRN/special/x86_64/special -mpi -c arg_dump_coreneuron_model=1 -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc
mv coredat coredat_gpu

# =============================================================================
nvidia-cuda-mps-control -d # Start the daemon

echo "----------------- CoreNEURON SIM (GPU_MOD2C) ----------------"
srun dplace $INSTALL_DIR/GPU_MOD2C/special/x86_64/special-core --mpi --voltage 1000. --gpu --cell-permute 2 --tstop $SIM_TIME -d coredat_gpu 2>&1 | tee GPU_MOD2C.log
# Sort the spikes
cat out.dat | sort -k 1n,1n -k 2n,2n > GPU_MOD2C.spk
rm out.dat

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
