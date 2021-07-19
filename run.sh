#!/bin/bash
#SBATCH -t 01:00:00
#SBATCH --partition=prod
#SBATCH -C"cpu|nvme"
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=36
#SBATCH --account=proj16

# Stop on error
set -e

# =============================================================================
# SIMULATION PARAMETERS TO EDIT
# =============================================================================

# set to one of: CPU, ISPC, GPU
BUILD_TYPE=ISPC

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

# GID for prcellstate (-1 for none)
export PRCELL_GID=281

# =============================================================================

# Enter the channel benchmark directory
cd $BASE_DIR/channels

# Run simulation with NEURON
echo "----------------- NEURON SIM ----------------"
srun dplace ./x86_64/special -mpi -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS -c arg_prcell_gid=$PRCELL_GID $HOC_LIBRARY_PATH/init.hoc 2>&1 | tee neuron.log

# Run simulation with CoreNEURON
echo "----------------- CoreNEURON SIM with in-memory transfer  ----------------"
srun dplace ./x86_64/special -mpi -c arg_coreneuron=1 -c arg_coreneuron_filemode=0  -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS -c arg_prcell_gid=$PRCELL_GID $HOC_LIBRARY_PATH/init.hoc 2>&1 | tee coreneuron.log

echo "----------------- CoreNEURON SIM with file Transfer  ----------------"
srun dplace ./x86_64/special -mpi -c arg_coreneuron=1 -c arg_coreneuron_filemode=1  -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS -c arg_prcell_gid=$PRCELL_GID $HOC_LIBRARY_PATH/init.hoc 2>&1 | tee coreneuron.log

echo "----------------- NEURON dump model and CoreNEURON with with file transfer ----------------"
srun dplace ./x86_64/special -mpi -c arg_tstop=$SIM_TIME -c arg_dump_coreneuron_model=1 -c arg_target_count=$NUM_CELLS -c arg_prcell_gid=$PRCELL_GID $HOC_LIBRARY_PATH/init.hoc 2>&1 | tee neuron.log
srun dplace ./x86_64/special-core --mpi -d coredat --prcellgid $PRCELL_GID 2>&1 | tee coreneuron.log

echo "----------------- SIM STATS -----------------"
echo "Number of ranks: "
grep "numprocs" neuron.log
echo "Number of cells: $NUM_CELLS"
echo "----------------- NEURON SIM STATS ----------------"
grep "psolve" neuron.log
echo "----------------- CoreNEURON SIM STATS ----------------"
grep "Solver Time" coreneuron.log

