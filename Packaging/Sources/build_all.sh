#!/bin/sh
# Build and install the full ArchSTEP stack in dependency order.
# Per-stage logs go to ~/build-logs; stops at the first failure.

LOGDIR=${HOME}/build-logs
mkdir -p ${LOGDIR}
cd "$(dirname "$0")" || exit 1

STAGES="
0_build_libdispatch.sh
1_build_libcorefoundation.sh
2_build_libobjc2.sh
3_build_core.sh
3_build_tools-make.sh
4_build_libwraster.sh
5_build_libs-base.sh
6_build_libs-gui.sh
7_build_libs-back.sh
8_build_Frameworks.sh
9_build_Applications.sh
"

for s in ${STAGES}; do
    echo "=== START ${s} $(date +%H:%M:%S)"
    ./${s} > ${LOGDIR}/${s}.log 2>&1 || { echo "=== FAILED ${s} (log: ${LOGDIR}/${s}.log)"; exit 1; }
    echo "=== OK ${s}"
done
echo "=== ALL_STAGES_OK"
