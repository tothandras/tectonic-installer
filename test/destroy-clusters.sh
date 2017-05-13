#!/bin/bash
# This script destroys all clusters in build directory

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TF_ROOT="$DIR/.."

if [ "${1}" != "-f" ]; then
    echo "This script will delete all clusters. To execute run ${0} -f"
    exit 1
fi

IGNORE_ERRORS=${IGNORE_ERRORS:-true}

for c in ${TF_ROOT}/build/*; do
  export CLUSTER=$(basename ${c})
  export TF_VAR_tectonic_cluster_name=$(echo ${CLUSTER} | awk '{print tolower($0)}')

  echo "Destroying ${CLUSTER}..."
  make destroy || ${IGNORE_ERRORS}
done