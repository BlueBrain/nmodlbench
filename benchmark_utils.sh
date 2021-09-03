#!/bin/bash
#SBATCH --account=proj16
#SBATCH --partition=prod_p2
#SBATCH --time=8:00:00
#SBATCH --nodes=1
#SBATCH --constraint=volta
#SBATCH --gres=gpu:1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=2
#SBATCH --exclusive
#SBATCH --mem=0

function run_benchmarks() {
  # Stop on error
  set -e
  # CPU or GPU? This controls if we pass --gpu and whether we use ~1 rank/GPU or ~1 rank/core.
  backend=$1

  # How many MPI ranks to use. For channel-benchmark the model behaviour/spikes
  # depend on this, so we cannot compare results if this changes.
  num_mpi=$2

  # How many GPUs to make available.
  num_gpus=$3

  # Which builds (=spack environments) to try and run.
  cnrn_configs="$4"

  # This is added to output filenames, it's passed in so that CPU/GPU results can be named consistently.
  date=$5
  
  # Types of profiling run to do:
  # none: do not attach a profiler
  # allmpi-nsys: launch srun inside nsys and get a single profile containing all processes on the zeroth node.
  # single-nsys: launch the zeroth rank on each node inside nsys.
  PROFILE_MODES="$6"

  # Using top level source and install directory, set the HOC_LIBRARY_PATH for simulator
  root_dir="${PWD}"
  output_prefix="${root_dir}/output"

  export HOC_LIBRARY_PATH=${root_dir}/benchmark/channels/lib/hoclib

  #Change this according to the desired runtime of the benchmark
  export SIM_TIME=10

  # Disable prcellstate.
  PRCELL_GID=-1

  # Number of cells ((LCM of #cores_system1, #core_system2)*#cell_types)
  # OL: this was the original comment but we seem to be ignoring it. IIUC there are 22 cell types.
  export NUM_CELLS=$((64*22))

  # Load external packages.
  # OL: if we want to use an older CUDA it might need to be included here.
  module load unstable hpe-mpi

  # Load Spack after the above modules, so we don't pick up modules from our private Spack installation.
  . ~/bin/setup_spack_env.sh

  # Show what we're using
  module list

  # Enter the channel benchmark directory, it seems that we need to run from here?
  cd ${root_dir}/benchmark/channels

  # Run NEURON to produce reference spikes. Do not put ${date} in here because
  # it's slow and tedious.
  neuron_output_prefix="${output_prefix}/neuron_${num_mpi}ranks"
  neuron_spikes="${neuron_output_prefix}/NRN.spk"
  if [[ -f "${neuron_spikes}" ]]
  then
    echo "Skipping creating ${neuron_spikes}"
  else
    echo "----------------- NEURON SIM (CPU) ----------------"
    (
      spack env activate ${root_dir}/spack-envs/neuron
      mkdir -p "${neuron_output_prefix}"
      srun -n ${num_mpi} dplace ${root_dir}/spack-specials/neuron/x86_64/special -mpi -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS -c arg_prcell_gid=$PRCELL_GID $HOC_LIBRARY_PATH/init.hoc |& tee "${neuron_output_prefix}/NRN.log"
      sort -k 1n,1n -k 2n,2n > "${neuron_spikes}" < out.dat
      rm out.dat
    )
  fi

  # Run NEURON to produce CoreNEURON input files. Don't put ${date} here
  # either for speed.
  cnrn_input_prefix="${output_prefix}/coreneuron_input_${num_mpi}ranks"
  if [[ -d "${cnrn_input_prefix}/coredat" ]]
  then
    echo "Skipping producing ${cnrn_input_prefix}/coredat"
  else
    echo "----------------- Produce coredat ----------------"
    (
      spack env activate ${root_dir}/spack-envs/neuron
      mkdir -p "${cnrn_input_prefix}"
      srun -n ${num_mpi} dplace ${root_dir}/spack-specials/neuron/x86_64/special -mpi -c arg_dump_coreneuron_model=1 -c arg_tstop=$SIM_TIME -c arg_target_count=$NUM_CELLS $HOC_LIBRARY_PATH/init.hoc |& tee "${cnrn_input_prefix}/NRN.log"
      mv coredat/ "${cnrn_input_prefix}/"
    )
  fi
  
  # Prefix for CoreNEURON results
  output_prefix_with_date="${output_prefix}/${date}"
  mkdir -p "${output_prefix_with_date}"
  output_profile_prefix="${output_prefix_with_date}/${backend}-${num_mpi}ranks"

  # Prepare to run CoreNEURON simulations...
  if [[ ${backend} == "gpu" ]]
  then
    nvidia-cuda-mps-control -d || true # Start the daemon
    prcellstate_slug="acc_gpu"
    gpu_arg="--gpu --cell-permute=2"
    output_profile_prefix="${output_profile_prefix}-${num_gpus}gpus"
  else
    prcellstate_slug="cpu"
  fi

  for cnrn in ${cnrn_configs}
  do
    echo "----------------- CoreNEURON SIM (${cnrn}) ----------------"
    (
      # Setup this CoreNEURON environment
      spack env activate "${root_dir}/spack-envs/${cnrn}"

      # Do runs with/without the profiler 
      for profile_mode in ${PROFILE_MODES}
      do
        echo "Running with profiler mode: ${profile_mode}"
        mkdir -p "${root_dir}/output"
        special_cmd="${root_dir}/spack-specials/${cnrn}/x86_64/special-core --voltage 1000. --mpi ${gpu_arg} --tstop ${SIM_TIME} -d ${cnrn_input_prefix}/coredat --prcellgid ${PRCELL_GID}"
        profile_prefix="${output_profile_prefix}-${cnrn}-${profile_mode}"

        echo Command: ${special_cmd}
        # nvtx: Caliper creates NVTX ranges that nsys can pick up
        # runtime-report: Caliper prints its own profiling table at the end of execution
        #export CALI_CONFIG="runtime-report(calc.inclusive)"
        #export CALI_SERVICES_ENABLE=debug
        #export CALI_LOG_VERBOSITY=100

        # Can also add this + mpiflush to CALI_SERVICES_ENABLE
        # export CALI_MPIREPORT_WRITE_ON_FINALIZE=false

        export CALI_CONFIG=nvtx
        export CALI_CHANNEL_FLUSH_ON_EXIT=false
        export CALI_MPIREPORT_FILENAME=${profile_prefix}-caliper.json
        export CALI_MPIREPORT_LOCAL_CONFIG='select sum(sum#time.duration), inclusive_sum(sum#time.duration) group by prop:nested'
        export CALI_MPIREPORT_CONFIG='SELECT annotation,
                                             min(inclusive#sum#time.duration) AS "inclusive_time_rank_min",
                                             max(inclusive#sum#time.duration) AS "inclusive_time_rank_max",
                                             avg(inclusive#sum#time.duration) AS "inclusive_time_rank_avg",
                                             inclusive_percent_total(sum#sum#time.duration) AS "Time %"
                                             GROUP BY prop:nested FORMAT json'
        export CALI_SERVICES_ENABLE=aggregate,event,mpi,mpireport,timestamp
        
        # Tell nsys that --capture-range=nvtx can be triggered by an NVTX range whose
        # name is not a registered string. Caliper does not use registered strings.
        export NSYS_NVTX_PROFILER_REGISTER_ONLY=0

        if [[ "${profile_mode}" == *"nsys"* ]]
        then
          if ! which nsys > /dev/null
          then
            echo "NSight Systems profiler nsys was not found, trying to load CUDA"
            module load cuda/11.0.2 # how to get <the deployed version>?
            module list
          fi
        fi
 
        srun_args="-n ${num_mpi} --gres=gpu:${num_gpus}"
        echo srun_args=${srun_args}
        if [[ ${profile_mode} == "none" ]];
        then
          srun ${srun_args} dplace ${special_cmd} |& tee "${profile_prefix}-0-CNRN.log"
        elif [[ ${profile_mode} == "allmpi-nsys" ]];
        then
          DO_PROFILE_MPI=yes sh ${root_dir}/launch_nsys.sh "${profile_prefix}" srun ${srun_args} dplace ${special_cmd}
        elif [[ ${profile_mode} == "single-nsys" ]];
        then
          srun ${srun_args} sh ${root_dir}/launch_nsys.sh "${profile_prefix}" dplace ${special_cmd}
        else
          echo "Profiling mode ${profile_mode} is not supported"
          exit 1
        fi
        if [[ ${profile_mode} != "none" ]]
        then
          suffix=-${profile_mode}
        fi
        sort -k 1n,1n -k 2n,2n > "${profile_prefix}.spk" < out.dat
        rm out.dat

        # Add some metadata to the Caliper output JSON file
        jq "{\"data\": ., \"build\": \"${cnrn}\", \"backend\": \"${backend}\"}" < "${CALI_MPIREPORT_FILENAME}" > "${CALI_MPIREPORT_FILENAME}.new"
        mv "${CALI_MPIREPORT_FILENAME}.new" "${CALI_MPIREPORT_FILENAME}"

        if [[ ${PRCELL_GID} > -1 ]]
        then
          formatted_sim_time=$(printf '%.6f' ${SIM_TIME})
          for suffix in init t0.000000 t${formatted_sim_time}
          do
            filename="${PRCELL_GID}_${prcellstate_slug}_${suffix}.corenrn"
            mv -v -- "${filename}" "${profile_prefix}-${filename}"
          done
        fi
      done
    )
  done

  if [[ $backend == "gpu" ]]
  then
    # Cleanup temporary files from nsys.
    find /tmp/nvidia/nsight_systems -mindepth 1 -maxdepth 1 -user ${USER} -type d -print0 | xargs -0 rm -rf
    # Shutdown the MPS daemon
    echo quit | nvidia-cuda-mps-control
  fi
}

function compare_results() {
  # Which input data/number of ranks/... to use, confusingly this is "cpu" for ~40 ranks or "gpu" for ~4 ranks
  launch_mode=$1
  # List of Spack environments
  coreneuron_builds=$2
  
  # TODO: print a list of execution times
  # echo "----------------- NEURON SIM STATS (CPU) ----------------"
  # grep "psolve" "${output_prefix}/neuron/NRN.log"
  # for cnrn in ${cnrn_configs}
  # do
  # for profile_mode in ${PROFILE_MODES}
  #do
  #  echo "----------------- CoreNEURON SIM (${cnrn} profile mode ${profile_mode}) STATS ----------------"
  #  grep "Solver Time" "${output_profile_prefix}-${cnrn}-${profile_mode}-0-CNRN.log"
  #done
  #done
  #echo "---------------------------------------------"
  output_prefix="${PWD}/output"
  for build1 in ${coreneuron_builds}
  do
    for build2 in ${coreneuron_builds}
    do
      if [[ ! "${build1}" > "${build2}" ]]
      then
        continue
      fi
      build1_dump=${output_prefix}/${build1}-${launch_mode}/*_t0.000000.corenrn
      build2_dump=${output_prefix}/${build2}-${launch_mode}/*_t0.000000.corenrn
      echo Comparing
      echo ${build1_dump}
      echo ${build2_dump}
      echo differ by $(diff ${build1_dump} ${build2_dump} | wc -l) lines
      build1_spikes=${output_prefix}/${build1}-${launch_mode}/CNRN.spk
      build2_spikes=${output_prefix}/${build2}-${launch_mode}/CNRN.spk
      diff -qs ${build1_spikes} ${build2_spikes}
    done
  done
  #echo "---------------------------------------------"
  #echo "-------------- Compare Spikes ---------------"
  #echo "---------------------------------------------"
  #for cnrn in ${cnrn_configs}
  #do
  #  cnrn_spikefile="${output_prefix}/${cnrn}/${cnrn}-${num_mpi}ranks-none.spk"
  #  diff=$(diff "${neuron_spikes}" "${cnrn_spikefile}" || true) 
  #  if [[ -n "${diff}" ]]
  #  then
  #    echo ${neuron_spikes} and ${cnrn_spikefile} differ 
  #  fi
  #done
}
