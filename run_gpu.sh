#!/bin/bash

#SBATCH --account=proj16
#SBATCH --time=08:00:00

#SBATCH --nodes=1
#SBATCH --constraint=volta
#SBATCH --gres=gpu:4
#SBATCH --ntasks-per-node=36

#SBATCH --cpus-per-task=2
#SBATCH --exclusive
#SBATCH --mem=0

# Stop on error
set -e

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

echo "----------------- Produce coredat ----------------"
srun dplace ../install/NRN/x86_64/special -mpi -c arg_dump_coreneuron_model=1 -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc

# =============================================================================

echo "----------------- CoreNEURON SIM (GPU_MOD2C) ----------------"
srun dplace ../install/GPU_MOD2C/x86_64/special-core --mpi --gpu --cell_permute=2 --tstop=$SIM_TIME -d coredat 2>&1 | tee GPU_MOD2C.log
mv out.dat GPU_MOD2C.dat

#echo "----------------- CoreNEURON SIM (GPU_NMODL) ----------------"
#srun dplace ../install/GPU_NMODL/x86_64/special-core --mpi --gpu --cell_permute=2 --tstop=$SIM_TIME -d coredat 2>&1 | tee GPU_NMODL.log
#mv out.dat GPU_NMODL.dat

# =============================================================================

echo "---------------------------------------------"
echo "----------------- SIM STATS -----------------"
echo "---------------------------------------------"

echo "Number of cells: $NUM_CELLS"
echo "----------------- CoreNEURON SIM (GPU_MOD2C) STATS ----------------"
grep "Solver Time" GPU_MOD2C.log
#echo "----------------- CoreNEURON SIM (GPU_NMODL) STATS ----------------"
#grep "Solver Time" GPU_NMODL.log

echo "---------------------------------------------"
echo "---------------------------------------------"
