#!/bin/bash

. ../env.sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DEPS_DIR=$( dirname -- "${SCRIPT_DIR}" )

ISPC_VERSION=$(sed -n 's/^version=//p' "${BASE_DEPS_DIR}/ISPC_VERSION")
if [ -z "${ISPC_VERSION}" ]; then
    echo "install_ispc: no version= line in ${BASE_DEPS_DIR}/ISPC_VERSION" >&2
    exit 1
fi
wget https://github.com/ispc/ispc/releases/download/${ISPC_VERSION}/ispc-${ISPC_VERSION}-macOS.universal.tar.gz
tar -xzf ispc-${ISPC_VERSION}-macOS.universal.tar.gz
cp ispc-${ISPC_VERSION}-macOS.universal/bin/ispc ${BASE_DEPS_DIR}/bin
rm -rf ispc-${ISPC_VERSION}-macOS.universal*
