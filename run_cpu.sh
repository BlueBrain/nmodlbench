#!/bin/bash

#SBATCH --account=proj16
# SBATCH --partition=prod
#SBATCH --time=01:00:00

#SBATCH --nodes=1
#SBATCH --constraint=volta
#SBATCH --gres=gpu:1
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

rm -rf coredat_cpu
rm NRN.dat CPU_MOD2C.dat CPU_NMODL.dat ISPC.dat
rm NRN.log CPU_MOD2C.log CPU_NMODL.log ISPC.log

echo "----------------- NEURON SIM (CPU) ----------------"
srun dplace ../install/NRN/x86_64/special -mpi -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc 2>&1 | tee NRN.log
mv out.dat NRN.dat

echo "----------------- Produce coredat ----------------"
srun dplace ../install/NRN/x86_64/special -mpi -c arg_dump_coreneuron_model=1 -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc
mv coredat coredat_cpu

echo "----------------- CoreNEURON SIM (CPU_MOD2C) ----------------"
srun dplace ../install/CPU_MOD2C/x86_64/special-core --mpi --voltage 1000. --tstop $SIM_TIME -d coredat_cpu 2>&1 | tee CPU_MOD2C.log
mv out.dat CPU_MOD2C.dat

echo "----------------- CoreNEURON SIM (CPU_NMODL) ----------------"
srun dplace ../install/CPU_NMODL/x86_64/special-core --mpi --voltage 1000. --tstop $SIM_TIME -d coredat_cpu 2>&1 | tee CPU_NMODL.log
mv out.dat CPU_NMODL.dat

echo "----------------- CoreNEURON SIM (ISPC) ----------------"
srun dplace ../install/ISPC/x86_64/special-core --mpi --voltage 1000. --tstop $SIM_TIME -d coredat_cpu 2>&1 | tee ISPC.log
mv out.dat ISPC.dat

# =============================================================================

echo "---------------------------------------------"
echo "----------------- SIM STATS -----------------"
echo "---------------------------------------------"

grep "numprocs" NRN.log
echo "Number of cells: $NUM_CELLS"
echo "----------------- NEURON SIM STATS (CPU) ----------------"
grep "psolve" NRN.log
echo "----------------- CoreNEURON SIM (CPU_MOD2C) STATS ----------------"
grep "Solver Time" CPU_MOD2C.log
echo "----------------- CoreNEURON SIM (CPU_NMODL) STATS ----------------"
grep "Solver Time" CPU_NMODL.log
echo "----------------- CoreNEURON SIM (ISPC) STATS ----------------"
grep "Solver Time" ISPC.log

echo "---------------------------------------------"
echo "---------------------------------------------"
