#!/bin/bash

# stop on error
set -e

# build and install directories
export BASE_DIR=$(pwd)/benchmark
export SOURCE_DIR=$BASE_DIR/sources
export BUILD_DIR=$BASE_DIR/build
export INSTALL_DIR=$BASE_DIR/install
mkdir -p $SOURCE_DIR $INSTALL_DIR

# Re-install -> Do not delete x86_64
# To re-install provide just an arbitrary arguement
if [ $# -eq 0 ]
then
    REINSTALL=0
else
    REINSTALL=1
fi

# =============================================================================
# 1. Setting source & build dependencies
# =============================================================================

# Modules to load typically on the cluster environment
# TODO: change the modules based on your environment
setup_modules() {
    printf "\n----------------- SETTING MODULES --------------\n"
    module purge
    module load unstable
    module load cmake git flex bison python-dev hpe-mpi
}

# TODO Adjust compiler loading according to your system

load_gcc() {
    module load gcc
    export CC=$(which gcc)
    export CXX=$(which g++)
}

unload_gcc() {
    module unload gcc
    unset CC
    unset CXX
}

load_intel() {
    module load intel
    export CC=$(which icc)
    export CXX=$(which icpc)
}

unload_intel() {
    module unload intel
    unset CC
    unset CXX
}

load_pgi_cuda() {
    module load nvhpc cuda
    export CC=$(which pgcc)
    export CXX=$(which pgc++)
}

unload_pgi_cuda() {
    module unload nvhpc cuda
    unset CC
    unset CXX
}

load_ispc() {
    module load ispc
    export ISPC=$(which ispc)
}

unload_ispc() {
    module unload ispc
    unset ISPC
}

# =============================================================================
# NO NEED TO EDIT BELLOW HERE
# =============================================================================

# Clone neuron repository
setup_source() {
    printf "\n----------------- CLONING REPO --------------\n"
    [[ -d $SOURCE_DIR/nrn ]] || git clone --recursive https://github.com/neuronsimulator/nrn.git $SOURCE_DIR/nrn
}

# Install python packages if not exist in standard environment
setup_python_packages() {
    printf "\n----------------- SETUP PYTHON PACKAGES --------------\n"
    [[ -d $SOURCE_DIR/venv ]] || python3 -mvenv $SOURCE_DIR/venv
    . $SOURCE_DIR/venv/bin/activate
    pip3 install Jinja2 PyYAML pytest "sympy<1.6"
}

# =============================================================================
# 2. Installing base software
# =============================================================================

# Install neuron which is used for building network model. This could be built with GNU
# toolchain as this is only used for input model generation.
install_neuron() {
    printf "\n----------------- INSTALL NEURON --------------\n"
    load_gcc
    mkdir -p $BUILD_DIR/neuron && pushd $BUILD_DIR/neuron
    cmake $SOURCE_DIR/nrn \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/NRN \
        -DNRN_ENABLE_INTERVIEWS=OFF \
        -DNRN_ENABLE_RX3D=OFF \
        -DNRN_ENABLE_CORENEURON=OFF \
        -DNRN_ENABLE_PYTHON=ON \
        -DPYTHON_EXECUTABLE=$(which python3) \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_gcc
}

# Install NMODL which is used for translating DSL to C++ code. This could be built with GNU
# toolchain as this is used as source-to-source compiler.
install_nmodl() {
    printf "\n----------------- INSTALL NMODL --------------\n"
    load_gcc
    mkdir -p $BUILD_DIR/nmodl && pushd $BUILD_DIR/nmodl
    cmake $SOURCE_DIR/nrn/external/coreneuron/external/nmodl \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/NMODL \
        -DPYTHON_EXECUTABLE=$(which python3) \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_gcc
}

# =============================================================================
# 3. Installing simulation engine
# =============================================================================

install_coreneuron_cpu_mod2c() {
    printf "\n----------------- INSTALL CORENEURON FOR CPU (MOD2C) --------------\n"
    load_intel
    mkdir -p $BUILD_DIR/cpu_mod2c && pushd $BUILD_DIR/cpu_mod2c
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/CPU_MOD2C \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_NMODL=OFF \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_intel
}

install_coreneuron_cpu_nmodl() {
    printf "\n----------------- INSTALL CORENEURON FOR CPU (NMODL) --------------\n"
    load_intel
    mkdir -p $BUILD_DIR/cpu_nmodl && pushd $BUILD_DIR/cpu_nmodl
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/CPU_NMODL \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_NMODL=ON \
        -DCORENRN_NMODL_DIR=$INSTALL_DIR/NMODL \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCORENRN_NMODL_FLAGS='sympy --analytic' \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_intel
}

install_coreneuron_gpu_mod2c()  {
    printf "\n----------------- INSTALL CORENEURON FOR GPU (MOD2C) --------------\n"
    load_pgi_cuda
    mkdir -p $BUILD_DIR/gpu_mod2c && pushd $BUILD_DIR/gpu_mod2c
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/GPU_MOD2C \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_GPU=ON \
        -DCORENRN_ENABLE_NMODL=OFF \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_pgi_cuda
}

install_coreneuron_gpu_nmodl()  {
    printf "\n----------------- INSTALL CORENEURON FOR GPU (NMODL) --------------\n"
    load_pgi_cuda
    mkdir -p $BUILD_DIR/gpu_nmodl && pushd $BUILD_DIR/gpu_nmodl
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/GPU_NMODL \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_GPU=ON \
        -DCORENRN_ENABLE_NMODL=ON \
        -DCORENRN_NMODL_DIR=$INSTALL_DIR/NMODL \
        -DCORENRN_NMODL_FLAGS='sympy --analytic' \ # given the resolved issues with eigen+openacc
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_pgi_cuda
}

install_coreneuron_ispc() {
    printf "\n----------------- INSTALL CORENEURON FOR CPU WITH ISPC --------------\n"
    load_ispc
    load_gcc
    mkdir -p $BUILD_DIR/ispc && pushd $BUILD_DIR/ispc
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/ISPC \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_NMODL=ON \
        -DCORENRN_NMODL_DIR=$INSTALL_DIR/NMODL \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCORENRN_ENABLE_ISPC=ON \
        -DCORENRN_NMODL_FLAGS="sympy --analytic" \
        -DCMAKE_BUILD_TYPE=Release
    make -j && make install
    popd
    unload_gcc
    unload_ispc
}

run_nrnivmodl() {
    cd $INSTALL_DIR/NRN
    # Delete any executables from previous runs
    if [ $REINSTALL == 0 ]
    then
        rm -rf x86_64 enginemech.o
    fi
    # Run nrnivmodl to generate the NEURON executable
    bin/nrnivmodl $BASE_DIR/channels/lib/modlib
}

# Provide the BUILD_TYPE as argument
run_nrnivmodl_core() {
    BUILD_TYPE=$1
    cd $INSTALL_DIR/$BUILD_TYPE
    # Delete any executables from previous runs
    if [ $REINSTALL == 0 ]
    then
        rm -rf x86_64 enginemech.o
    fi
    # Run nrnivmodl-core to generate the CoreNEURON library
    bin/nrnivmodl-core $BASE_DIR/channels/lib/modlib
}

# 1. Setting source & build dependencies
setup_source
setup_modules
setup_python_packages

# 2. Installing base software
install_neuron
install_nmodl

# 3. Installing simulation engine
install_coreneuron_cpu_mod2c
install_coreneuron_cpu_nmodl
install_coreneuron_gpu_mod2c
#install_coreneuron_gpu_nmodl
install_coreneuron_ispc

# 4. Generate library
run_nrnivmodl
run_nrnivmodl_core CPU_MOD2C
run_nrnivmodl_core CPU_NMODL
run_nrnivmodl_core GPU_MOD2C
#run_nrnivmodl_core GPU_NMODL
run_nrnivmodl_core ISPC
