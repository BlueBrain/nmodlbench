#!/bin/sh
out_prefix="$1"
shift
logfile="${out_prefix}-${SLURM_PROCID}-CNRN.log"
if [[ $SLURM_LOCALID == 0 ]]; then
  nsys profile --stats=true \
    -o "${out_prefix}-%q{SLURM_PROCID}" \
    --verbose --wait=all --kill=none \
    --capture-range=nvtx \
    '--nvtx-capture=simulation@*' \
    --trace=cuda,nvtx,osrt,openacc,openmp${DO_PROFILE_MPI:+,mpi} \
    "$@" |& tee "${logfile}" 
else
  "$@" > "${logfile}" 2>&1
fi
