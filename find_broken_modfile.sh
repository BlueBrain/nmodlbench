#!/usr/bin/env bash

set -ex

export BASE_DIR=$(pwd)/benchmark
export SOURCE_DIR=$BASE_DIR/sources
export BUILD_DIR=$BASE_DIR/build
export INSTALL_DIR=$BASE_DIR/install

run_nrnivmodl() {
    mkdir -p $INSTALL_DIR/NRN/special && pushd $INSTALL_DIR/NRN/special
    # Delete any executables from previous runs
    rm -rf x86_64
    # compile all of them again with NOCMODL
    nrnivmodl $BASE_DIR/channels/lib/modlib &> /dev/null
    if [ -n "$1" ]
    then
        # the name of the modfile (NO EXTENSION!)
        modfile_to_compile="$1"
        # remove the old one
        rm -fr ${INSTALL_DIR}/NRN/special/x86_64/${modfile_to_compile}.{cpp,o}
        # only compile and link that one with NMODL
        nrnivmodl -nmodl $(which nmodl) ${BASE_DIR}/channels/lib/modlib/${modfile_to_compile}.mod &> /dev/null
        # rerun for good measure
        nrnivmodl $BASE_DIR/channels/lib/modlib &> /dev/null
    fi
    popd
}

for path in ${BASE_DIR}/channels/lib/modlib/CaDynamics_DC0.mod
do
    name="$(basename "${path}")"
    echo "Attempting to run with NMODLd modfile ${name}"
    run_nrnivmodl "${name%.mod}"
    if ! bash run_cpu.sh
    then
        echo "!!!!!ATTENTION!!!!!"
        echo "==================="
        echo "FOUND BROKEN MODFILE: ${name}"
        echo "==================="
    fi
done
