#!/bin/bash

# stop on error
set -e

# build and install directories
export BASE_DIR=$(pwd)/benchmark
export SOURCE_DIR=$BASE_DIR/sources
export BUILD_DIR=$BASE_DIR/build
export INSTALL_DIR=$BASE_DIR/install
mkdir -p $SOURCE_DIR $INSTALL_DIR

# =============================================================================
# 1. Setting source & build dependencies
# =============================================================================

# Modules to load typically on the cluster environment
# TODO: change the modules based on your environment
setup_modules() {
    printf "\n----------------- SETTING MODULES --------------\n"
    module purge
    module load unstable
    module load cmake/3.15.3 flex/2.6.3 bison/3.0.5 python/3.7.4 hpe-mpi/2.21
}

# TODO Adjuct compiler loading according to your system

load_gcc() {
    module load gcc/8.3.0
    export CC=$(which gcc)
    export CXX=$(which g++)
}

unload_gcc() {
    module unload gcc
    unset CC
    unset CXX
}

load_intel() {
    module load intel/19.0.4
    export CC=$(which icc)
    export CXX=$(which icpc)
}

unload_intel() {
    module unload intel
    unset CC
    unset CXX
}

load_pgi_cuda() {
    module load pgi/19.10 cuda/10.1.243
    export CC=$(which pgcc)
    export CXX=$(which pgc++)
}

unload_pgi_cuda() {
    module unload pgi cuda
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
# 2. Installing base softwares
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
        -DCMAKE_BUILD_TYPE=Debug
    make -j16 && make install
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
    make -j16 && make install
    popd
    unload_gcc
}

# =============================================================================
# 3. Installing simulation engine
# =============================================================================

# CoreNEURON is used as simulation engine and should be compiled with optimal flags.
# Here we build two configurations with vendor compilers : Intel compiler for CPU
# build and PGI compiler for OpenACC based GPU build. Note that Intel compiler is
# typically used on Intel & AMD platforms to enable auto-vectorisation.

install_coreneuron_cpu()  {
    printf "\n----------------- INSTALL CORENEURON FOR CPU --------------\n"
    load_intel
    mkdir -p $BUILD_DIR/cpu && pushd $BUILD_DIR/cpu
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/CPU \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_NMODL=ON \
        -DCORENRN_NMODL_DIR=$INSTALL_DIR/NMODL \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCORENRN_NMODL_FLAGS='sympy --analytic' \
        -DCMAKE_BUILD_TYPE=Release
    make -j16 && make install
    popd
    unload_intel
}

install_coreneuron_gpu()  {
    printf "\n----------------- INSTALL CORENEURON FOR GPU --------------\n"
    load_pgi_cuda
    mkdir -p $BUILD_DIR/gpu && pushd $BUILD_DIR/gpu
    cmake $SOURCE_DIR/nrn/external/coreneuron \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/GPU \
        -DCORENRN_ENABLE_UNIT_TESTS=OFF \
        -DCORENRN_ENABLE_OPENMP=OFF \
        -DCORENRN_ENABLE_GPU=ON \
        -DCORENRN_ENABLE_NMODL=ON \
        #-DCORENRN_NMODL_FLAGS='sympy --analytic' \ # sympy disabled for gpu build due to issues with eigen+openacc
        -DCORENRN_NMODL_DIR=$INSTALL_DIR/NMODL \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_BUILD_TYPE=Release
    make -j16 && make install
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
        -DCMAKE_BUILD_TYPE=Debug
    make -j16 && make install
    popd
    unload_gcc
    unload_ispc
}

run_nrnivmodl() {
    # Enter the channel benchmark directory
    cd $BASE_DIR/channels
    # Delete any executables from previous runs
    rm -rf x86_64 enginemech.o
    # Run nrnivmodl to generate the NEURON executable
    $INSTALL_DIR/NRN/bin/nrnivmodl lib/modlib
}

# Provide the BUILD_TYPE as argument
run_nrnivmodl_core() {
    # Enter the channel benchmark directory
    cd $BASE_DIR/channels
    BUILD_TYPE=$1
    # Run nrnivmodl-core to generate the CoreNEURON library
    $INSTALL_DIR/$BUILD_TYPE/bin/nrnivmodl-core lib/modlib
}

setup_source
setup_modules
setup_python_packages
install_neuron
install_nmodl
install_coreneuron_ispc
run_nrnivmodl
run_nrnivmodl_core ISPC

