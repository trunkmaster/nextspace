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
    [ -S "${MONITOR}" ] || { echo "No monitor socket - VM not running?"; exit 1; }
    echo system_powerdown | nc -U -q1 "${MONITOR}" > /dev/null
    echo "Sent ACPI powerdown."
    exit 0
fi

[ -f "${DISK}" ] || { echo "No disk. Run ./setup.sh first."; exit 1; }
if [ -f "${PIDFILE}" ] && kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
    echo "VM already running (pid $(cat "${PIDFILE}"))."
    exit 0
fi

# Serial console: interactive via unix socket, mirrored to console.log
SERIAL="-chardev socket,id=ser0,path=${IMAGES}/serial.sock,server=on,wait=off,logfile=${IMAGES}/console.log
    -serial chardev:ser0"

COMMON="-enable-kvm -cpu host -smp ${CPUS} -m ${MEM}
    -drive file=${DISK},if=virtio
    -cdrom ${IMAGES}/seed.iso
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22
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
