#!/bin/sh
# Prepare the ArchSTEP test VM: ssh key, cloud-init seed, disk overlay.
# Requires: qemu-img, xorriso, ssh-keygen. Base image is downloaded by
# fetch-image.sh (or manually) into vm/images/.

set -e
VM_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES="${VM_DIR}/images"
KEYS="${VM_DIR}/keys"
BASE_IMAGE="${IMAGES}/Arch-Linux-x86_64-cloudimg.qcow2"
DISK="${IMAGES}/archstep.qcow2"
DISK_SIZE=40G

[ -f "${BASE_IMAGE}" ] || { echo "Base image missing: ${BASE_IMAGE}"; echo "Run: ./fetch-image.sh"; exit 1; }

mkdir -p "${KEYS}"
if [ ! -f "${KEYS}/archstep_ed25519" ]; then
    ssh-keygen -q -t ed25519 -N "" -C "archstep-vm" -f "${KEYS}/archstep_ed25519"
    echo "Generated ssh key: ${KEYS}/archstep_ed25519"
fi
PUBKEY=$(cat "${KEYS}/archstep_ed25519.pub")

# cloud-init NoCloud seed
CIDATA="${IMAGES}/cidata"
mkdir -p "${CIDATA}"
cat > "${CIDATA}/user-data" <<EOF
#cloud-config
hostname: archstep-vm
ssh_pwauth: true
users:
  - name: arch
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - ${PUBKEY}
chpasswd:
  expire: false
  users:
    - name: arch
      password: archstep
      type: text
packages:
  - git
  - rsync
runcmd:
  - systemctl enable --now sshd.service
# bootcmd runs early on every boot:
# - slirp's DNS proxy (10.0.2.3) only forwards to the host's *first*
#   nameserver, which may be unreachable from here; use real resolvers.
# - the guest clock is already correct via kvm-clock; without the mask,
#   time-sync.target blocks multi-user, cloud-final and sshd forever when
#   NTP can't resolve.
bootcmd:
  - mkdir -p /etc/systemd/resolved.conf.d
  - printf '[Resolve]\nDNS=1.1.1.1 9.9.9.9\nDomains=~.\n' > /etc/systemd/resolved.conf.d/vm-dns.conf
  - systemctl try-restart systemd-resolved.service
  - systemctl mask --now systemd-time-wait-sync.service
EOF
cat > "${CIDATA}/meta-data" <<EOF
instance-id: archstep-vm-001
local-hostname: archstep-vm
EOF
xorriso -as mkisofs -quiet -output "${IMAGES}/seed.iso" \
        -volid CIDATA -joliet -rock "${CIDATA}/user-data" "${CIDATA}/meta-data"
echo "Built cloud-init seed: ${IMAGES}/seed.iso"

# Copy-on-write overlay so the pristine base image is never touched.
# Re-running setup.sh after removing archstep.qcow2 gives a factory reset.
if [ -f "${DISK}" ]; then
    echo "Disk overlay already exists: ${DISK} (delete it to reset the VM)"
else
    qemu-img create -q -f qcow2 -F qcow2 -b "${BASE_IMAGE}" "${DISK}" ${DISK_SIZE}
    echo "Created ${DISK_SIZE} disk overlay: ${DISK}"
fi
echo "Done. Start the VM with: ./run.sh"
