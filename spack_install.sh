set -e
root_dir="${PWD}"
concurrent_jobs="36"

clone_project() { 
  name="$1"
  url="$2"
  if [[ ! -d "${root_dir}/spack-src-dirs/${name}" ]]
  then
    git clone "${url}" "${root_dir}/spack-src-dirs/${name}"
  fi
}

configured_environments=""
setup_environment() {
  env_name=$1
  if [ -z "${SKIP_BUILD}" ]
  then
    env_dir="${root_dir}/spack-envs/${env_name}"
    if [ -z "${SKIP_ENV}" ]
    then
      echo Removing ${env_dir}
      rm -rf "${env_dir}"
      mkdir -p "${env_dir}"
      cp "${root_dir}/spack-template.yaml" "${env_dir}/spack.yaml"
    fi
    spack env activate "${env_dir}"
    if [ -z "${SKIP_ENV}" ]
    then
      spack add jq%gcc
      shift
      for spec in "$@"
      do
        package=$(echo ${spec} | cut -d @ -f 1)
        spack add "${spec}"
        if [[ -d "${root_dir}/spack-src-dirs/${package}" ]]
        then
          spack develop -p "${root_dir}/spack-src-dirs/${package}" "${spec}"
        fi
      done
      spack concretize -f
    fi
    spack install -j ${concurrent_jobs}
    spack env deactivate
  fi
  configured_environments="${configured_environments} ${env_name}"
}

# Make sure a modern GCC is first in $PATH
module load unstable gcc

# Make sure Spack is available
. ~/bin/setup_spack_env.sh

# Make sure we have checkouts of the key projects.
# Spack falls over if you ask it to do this itself :-(
clone_project nmodl      git@github.com:BlueBrain/nmodl.git
clone_project neuron     git@github.com:neuronsimulator/nrn.git
clone_project coreneuron git@github.com:BlueBrain/CoreNeuron.git

# Create and install the various environments.
NMODL_SPEC="nmodl@develop%gcc~legacy-unit"
CUDA_SPEC="cuda@11.4.0%gcc ^libiconv%gcc"
CALIPER_SPEC="caliper%gcc@2.6.0:+cuda cuda_arch=70"
CORENEURON_VARIANTS="+caliper~legacy-unit~report"
setup_environment neuron neuron@develop%gcc~legacy-unit~rx3d
setup_environment coreneuron_cpu_mod2c coreneuron@develop%intel${CORENEURON_VARIANTS}~gpu~ispc~nmodl~sympy "${CALIPER_SPEC}"
setup_environment coreneuron_gpu_mod2c coreneuron@develop%nvhpc@21.7${CORENEURON_VARIANTS}+gpu~ispc~nmodl~sympy "${CALIPER_SPEC}" "${CUDA_SPEC}"
#setup_environment coreneuron_cpu_mod2c_nvhpc coreneuron@develop%nvhpc@21.5${CORENEURON_VARIANTS}~gpu~ispc~nmodl~sympy "${CALIPER_SPEC}"
#setup_environment coreneuron_cpu_mod2c_nvhpc_debug "coreneuron@develop%nvhpc@21.5${CORENEURON_VARIANTS}~gpu~ispc~nmodl~sympy build_type=Debug" "${CALIPER_SPEC}"
#setup_environment coreneuron_gpu_mod2c_debug "coreneuron@develop%nvhpc@21.5${CORENEURON_VARIANTS}+gpu~ispc~nmodl~sympy build_type=Debug" "${CALIPER_SPEC}" "${CUDA_SPEC}"
#setup_environment coreneuron_gpu_mod2c_cuda110 coreneuron@develop%nvhpc@21.2${CORENEURON_VARIANTS}+gpu~ispc~nmodl~sympy "${CALIPER_SPEC}"
#setup_environment coreneuron_cpu_ispc  coreneuron@develop%intel${CORENEURON_VARIANTS}~gpu+ispc+nmodl+sympy "${CALIPER_SPEC}" "${NMODL_SPEC}"
#setup_environment coreneuron_cpu_nmodl coreneuron@develop%intel${CORENEURON_VARIANTS}~gpu~ispc+nmodl+sympy "${CALIPER_SPEC}" "${NMODL_SPEC}"
#setup_environment coreneuron_gpu_nmodl coreneuron@develop%nvhpc@21.2${CORENEURON_VARIANTS}+gpu~ispc+nmodl+sympy "${CALIPER_SPEC}" "${NMODL_SPEC}"

compile_mechs() {
  env_name="$1"
  nrnivmodl="$2"
  working_dir="${root_dir}/spack-specials/${env_name}"
  mkdir -p "${working_dir}"
  (spack env activate "${root_dir}/spack-envs/${env_name}" && cd "${working_dir}" && "${nrnivmodl}" ${root_dir}/benchmark/channels/lib/modlib)
}

# Translate/compile the various mechanisms
compile_mechs neuron nrnivmodl
for coreneuron_env in ${configured_environments}
do
  if [[ ${coreneuron_env} == "neuron" ]]; then continue; fi
  compile_mechs ${coreneuron_env} nrnivmodl-core
done
