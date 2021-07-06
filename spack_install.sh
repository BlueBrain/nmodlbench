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

setup_environment() {
  env_name=$1
  env_dir="${root_dir}/${env_name}"
  mkdir "${env_dir}" || true
  cp -v "${root_dir}/spack-template.yaml" "${env_dir}/spack.yaml"
  shift
  spack env activate "${env_dir}"
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
  spack install -j ${concurrent_jobs}
}
# Make sure Spack is available
. ~/bin/setup_spack_env.sh

# Make sure we have checkouts of the key projects. Spack falls over if you ask it to do this itself :-(
clone_project nmodl      git@github.com:BlueBrain/nmodl.git
clone_project neuron     git@github.com:neuronsimulator/nrn.git
clone_project coreneuron git@github.com:BlueBrain/CoreNeuron.git

# Create and install the various environments.
NMODL_SPEC="nmodl@develop%gcc~legacy-unit"
CALIPER_SPEC="caliper%gcc@2.6.0:+cuda cuda_arch=70"
CORENEURON_VARIANTS="+caliper~legacy-unit~report"
setup_environment neuron neuron@develop%gcc~legacy-unit~rx3d
setup_environment coreneuron_cpu_mod2c coreneuron@develop%intel${CORENEURON_VARIANTS}~gpu~ispc~nmodl~sympy "${CALIPER_SPEC}"
setup_environment coreneuron_gpu_mod2c coreneuron@develop%nvhpc${CORENEURON_VARIANTS}+gpu~ispc~nmodl~sympy "${CALIPER_SPEC}"
setup_environment coreneuron_cpu_ispc  coreneuron@develop%intel${CORENEURON_VARIANTS}~gpu+ispc+nmodl+sympy "${CALIPER_SPEC}" "${NMODL_SPEC}"
setup_environment coreneuron_cpu_nmodl coreneuron@develop%intel${CORENEURON_VARIANTS}~gpu~ispc+nmodl+sympy "${CALIPER_SPEC}" "${NMODL_SPEC}"
setup_environment coreneuron_gpu_nmodl coreneuron@develop%nvhpc${CORENEURON_VARIANTS}+gpu~ispc+nmodl+sympy "${CALIPER_SPEC}" "${NMODL_SPEC}"

#env_dir="channel-benchmark-test-env2"
#spack_yaml="${env_dir}/spack.yaml"
#mkdir "${env_dir}" || true
#cp -v spack-template.yaml "${spack_yaml}"
#create_environment_config_with_externals() {
#  for spec in "$@"
#  do
#    if spack find "${spec}"
#    then
#      echo External ${spec} already found, not installing it.
#    else
#      echo Installing ${spec}
#      spack install -j 8
#for spec in "${CALIPER_SPEC}"
#do
#  if spack find "${spec}"
#  then
#    echo "${spec} already found"
#  else
#    echo "Installing ${spec}"
#    spack install -j 8 "${spec}"
#  fi
#done
#spack export --module tcl "${CALIPER_SPEC}" | sed -e 's/^/  /' >> "${spack_yaml}"
#}
#CALIPER_SPEC="caliper@2.6.0:+cuda cuda_arch=70"

