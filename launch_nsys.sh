#!/bin/sh
out_prefix="$1"
shift
if [[ $SLURM_LOCALID == 0 ]]; then
  nsys profile --stats=true \
    -o "${out_prefix}" \
    --verbose --wait=all --kill=none \
    --capture-range=nvtx \
    '--nvtx-capture=simulation@*' \
    --trace=cuda,nvtx,osrt,openacc,openmp \
    "$@" 
else
  "$@"
fi
