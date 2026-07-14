#!/bin/sh
# Download the latest official Arch Linux cloud image into vm/images/.
set -e
VM_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${VM_DIR}/images"
cd "${VM_DIR}/images"
curl -fLO --retry 3 https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
ls -lh Arch-Linux-x86_64-cloudimg.qcow2
