#!/bin/sh
# Run the ArchSTEP test VM.
#   ./run.sh            headless, daemonized; ssh via ./ssh.sh
#   ./run.sh --graphic  foreground with a display window (for M3+ testing)
#   ./run.sh --stop     power off the VM via the QEMU monitor
set -e
VM_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES="${VM_DIR}/images"
DISK="${IMAGES}/archstep.qcow2"
PIDFILE="${IMAGES}/qemu.pid"
MONITOR="${IMAGES}/monitor.sock"
SSH_PORT=2222
MEM=8192
CPUS=8

if [ "$1" = "--stop" ]; then
    PID=""
    [ -f "${PIDFILE}" ] && PID=$(cat "${PIDFILE}")
    if [ -z "${PID}" ] || ! kill -0 "${PID}" 2>/dev/null; then
        echo "VM not running."
        exit 0
    fi
    # 1. ACPI power button - ignored when an active desktop session
    #    inhibits it (logind defers to the session)
    echo system_powerdown | nc -U -q1 "${MONITOR}" > /dev/null
    echo "Sent ACPI powerdown, waiting..."
    for i in $(seq 1 10); do
        kill -0 "${PID}" 2>/dev/null || { echo "VM stopped."; exit 0; }
        sleep 1
    done
    # 2. Clean shutdown over ssh
    echo "Guest ignored ACPI (active session?); trying ssh poweroff..."
    ssh -p 2222 -i "${VM_DIR}/keys/archstep_ed25519" \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile="${IMAGES}/known_hosts" \
        -o ConnectTimeout=5 arch@127.0.0.1 'sudo poweroff' 2>/dev/null
    for i in $(seq 1 20); do
        kill -0 "${PID}" 2>/dev/null || { echo "VM stopped."; exit 0; }
        sleep 1
    done
    # 3. Last resort: kill QEMU (unclean for the guest filesystem)
    echo "Still alive; hard-stopping QEMU."
    echo quit | nc -U -q1 "${MONITOR}" > /dev/null
    exit 0
fi

[ -f "${DISK}" ] || { echo "No disk. Run ./setup.sh first."; exit 1; }
if [ -f "${PIDFILE}" ] && kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
    echo "VM already running (pid $(cat "${PIDFILE}"))."
    exit 0
fi

# Audio: route guest HDA to whatever the host actually runs;
# fall back to a silent backend so the guest still gets a sound card.
if pactl info >/dev/null 2>&1; then
    AUDIO_BACKEND=pa
elif [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipewire-0" ]; then
    AUDIO_BACKEND=pipewire
else
    AUDIO_BACKEND=none
fi

# Serial console: interactive via unix socket, mirrored to console.log
SERIAL="-chardev socket,id=ser0,path=${IMAGES}/serial.sock,server=on,wait=off,logfile=${IMAGES}/console.log
    -serial chardev:ser0"

COMMON="-enable-kvm -machine q35 -cpu host -smp ${CPUS} -m ${MEM}
    -drive file=${DISK},if=virtio
    -cdrom ${IMAGES}/seed.iso
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22
    -audiodev ${AUDIO_BACKEND},id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0
    -device qemu-xhci,id=xhci
    -monitor unix:${MONITOR},server,nowait
    -pidfile ${PIDFILE}"

if [ "$1" = "--graphic" ]; then
    exec qemu-system-x86_64 ${COMMON} ${SERIAL} -device virtio-vga -display gtk
else
    qemu-system-x86_64 ${COMMON} ${SERIAL} -display none -daemonize
    echo "VM started headless (console log: vm/images/console.log)."
    echo "Connect with: ./ssh.sh   (user: arch, ssh port ${SSH_PORT})"
    echo "Serial console: socat - UNIX-CONNECT:images/serial.sock"
fi
