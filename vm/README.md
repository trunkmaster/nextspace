# ArchSTEP test VM

QEMU/KVM harness for testing ArchSTEP on a disposable, always-current Arch
Linux guest (official cloud image + cloud-init). Images and keys live under
`vm/images/` and `vm/keys/` — both gitignored.

Host requirements: `qemu-desktop`, `xorriso`, `rsync`, `openbsd-netcat`
(all in the official repos; `socat` optional for the serial console).

## Workflow

```
./fetch-image.sh    # download latest Arch cloud image (~500 MB, once)
./setup.sh          # ssh key + cloud-init seed + 40G copy-on-write disk
./run.sh            # boot headless (first boot: cloud-init provisions, ~1 min)
./ssh.sh            # log in (user: arch, passwordless sudo)
./sync.sh           # rsync working tree -> VM:~/ArchSTEP
./run.sh --stop     # ACPI powerdown
./run.sh --graphic  # boot with a display window (M3+: Login.app/Workspace)
```

Build inside the VM:
```
./ssh.sh
cd ArchSTEP/Packaging/Sources
./0_build_libdispatch.sh && ./1_build_libcorefoundation.sh && ...
```

## Reset / snapshots

- **Factory reset:** stop the VM, `rm images/archstep.qcow2`, re-run `./setup.sh`.
  The overlay is copy-on-write over the pristine base image.
- **Snapshots** (VM must be stopped):
  `qemu-img snapshot -c NAME images/archstep.qcow2` (create),
  `-a NAME` (revert), `-l` (list), `-d NAME` (delete).
  Take one after a successful full build (`v1-baseline`).

Console password login (VESA console via `--graphic`): user `arch`,
password `archstep`.
