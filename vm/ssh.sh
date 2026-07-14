#!/bin/sh
# ssh into the ArchSTEP test VM. Extra args are passed to ssh,
# e.g.: ./ssh.sh 'uname -a'
VM_DIR="$(cd "$(dirname "$0")" && pwd)"
exec ssh -p 2222 -i "${VM_DIR}/keys/archstep_ed25519" \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="${VM_DIR}/images/known_hosts" \
    arch@127.0.0.1 "$@"
