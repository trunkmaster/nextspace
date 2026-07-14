#!/bin/sh
# rsync the working tree into the VM at ~/ArchSTEP (excludes VM images
# and build trees). Run after every local change you want to test.
set -e
VM_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "${VM_DIR}")"
exec rsync -a --delete \
    --exclude .git --exclude vm/images --exclude vm/keys \
    --exclude BUILD_ROOT --exclude docs \
    -e "ssh -p 2222 -i ${VM_DIR}/keys/archstep_ed25519 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${VM_DIR}/images/known_hosts" \
    "${REPO_DIR}/" arch@127.0.0.1:ArchSTEP/
