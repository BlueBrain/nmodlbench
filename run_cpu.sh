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
set -ex

# =============================================================================
# SIMULATION PARAMETERS TO EDIT
# =============================================================================

# Using top level source and install directory, set the HOC_LIBRARY_PATH for simulator
BASE_DIR=$(pwd)/benchmark
INSTALL_DIR=$BASE_DIR/install
SOURCE_DIR=$BASE_DIR/sources
#
export HOC_LIBRARY_PATH=$BASE_DIR/channels/lib/hoclib
#. $SOURCE_DIR/venv/bin/activate
#export PYTHONPATH=$INSTALL_DIR/NRN/lib/python:$PYTHONPATH

#Change this according to the desired runtime of the benchmark
export SIM_TIME=10

# Number of cells ((LCM of #cores_system1, #core_system2)*#cell_types)
export NUM_CELLS=$((3*2))

# GID for prcellstate (-1 for none)
export PRCELL_GID=-1

# =============================================================================

# Enter the channel benchmark directory
cd $BASE_DIR/channels

rm -rf coredat_cpu
rm -fr NRN_CPU.spk CPU_MOD2C.spk CPU_NMODL.spk ISPC.spk
rm -fr NRN_CPU.log CPU_MOD2C.log CPU_NMODL.log ISPC.log

echo "----------------- NEURON SIM (CPU) ----------------"
$INSTALL_DIR/NRN/special/x86_64/special -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS -c arg_prcell_gid=$PRCELL_GID $HOC_LIBRARY_PATH/init.hoc
# Sort the spikes
cat out.dat | sort -k 1n,1n -k 2n,2n > NRN_CPU.spk
rm -fr out.dat

echo "----------------- Produce coredat ----------------"
$INSTALL_DIR/NRN/special/x86_64/special -c arg_dump_coreneuron_model=1 -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc
mv coredat coredat_cpu

echo "----------------- CoreNEURON SIM (CPU_MOD2C) ----------------"
$INSTALL_DIR/CPU_MOD2C/special/x86_64/special-core --voltage 1000. --tstop $SIM_TIME -d coredat_cpu --prcellgid $PRCELL_GID 2>&1 | tee CPU_MOD2C.log
# Sort the spikes
cat out.dat | sort -k 1n,1n -k 2n,2n > CPU_MOD2C.spk
rm -fr out.dat

echo "----------------- CoreNEURON SIM (CPU_NMODL) ----------------"
$INSTALL_DIR/CPU_NMODL/special/x86_64/special-core --voltage 1000. --tstop $SIM_TIME -d coredat_cpu --prcellgid $PRCELL_GID 2>&1 | tee CPU_NMODL.log
# Sort the spikes
cat out.dat | sort -k 1n,1n -k 2n,2n > CPU_NMODL.spk
rm -fr out.dat


# =============================================================================

echo "---------------------------------------------"
echo "-------------- Compare Spikes ---------------"
echo "---------------------------------------------"

DIFF="$(diff NRN_CPU.spk CPU_MOD2C.spk)"
if [ -n "$DIFF" ]
then
    echo "NRN_CPU.spk CPU_MOD2C.spk are not the same, diff is:"
    echo "${DIFF}"
    exit 1
else
    echo "NRN_CPU.spk CPU_MOD2C.spk are the same"
fi

DIFF="$(diff NRN_CPU.spk CPU_NMODL.spk)"
if [ -n "$DIFF" ]
then
    echo "NRN_CPU.spk CPU_NMODL.spk are not the same, diff is:"
    echo "${DIFF}"
    exit 1
else
    echo "NRN_CPU.spk CPU_NMODL.spk are the same"
fi
