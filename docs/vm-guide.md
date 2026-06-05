# Install Nexos In A VM From ISO

This guide starts from a machine that has Nix installed and builds a Nexos ISO.
You then boot that ISO in a VM, install Nexos to a virtual disk, reboot, and use
`nex` inside the installed system.

## 1. Check Prerequisites

You need:

- Linux with KVM/QEMU support
- Nix with flakes enabled
- At least 4 GiB RAM for the VM
- A virtual disk of at least 20 GiB

Set the source flake. While this repo is still local and unpublished, use the
checkout path:

```sh
export NEXOS_SOURCE="path:/home/nate/Projects/Github/nexos"
```

After the repo is pushed, this can become:

```sh
export NEXOS_SOURCE="github:halcyonomega/nexos"
```

Check that Nix can run the Nexos CLI from the flake:

```sh
nix run "$NEXOS_SOURCE#nex" -- --help
```

For the rest of this guide, use this helper so commands look like the final
Nexos experience before `nex` is installed system-wide:

```sh
alias nex='nix run "$NEXOS_SOURCE#nex" --'
```

## 2. Build The Nexos ISO

Build the installer ISO:

```sh
nex pkg build "$NEXOS_SOURCE#iso"
```

The ISO will be in:

```sh
ls result/iso
```

The ISO currently includes:

- `nex`
- `nh`
- flakes enabled
- `/etc/nexos-release`
- GNOME with the Calamares graphical installer
- a baseline `/etc/nexos` flake using flake-parts, import-tree, and
  `nexos.lib.nexosSystem`
- installed systems use `/etc/nexos` only; legacy `/etc/nixos` is removed at
  install time
- hardware config is generated to `hosts/vm/hardware.nix` during install

## 3. Create A Virtual Disk

Create a disk image:

```sh
qemu-img create -f qcow2 nexos.qcow2 30G
```

## 4. Boot The ISO

Boot the installer:

```sh
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 2 \
  -drive file=nexos.qcow2,if=virtio,format=qcow2 \
  -cdrom result/iso/nexos.iso \
  -boot d \
  -display gtk
```

If the ISO filename includes a version suffix, use the actual file:

```sh
ls result/iso
```

You can also use virt-manager:

- Create a new VM
- Choose “local install media”
- Select the Nexos ISO from `result/iso`
- Create or attach a 30 GiB disk
- Boot the VM

## 5. Install Nexos

The live session logs in as `nexos` with password `password` and starts the default NixOS graphical installer.
Use the installer for the normal guided VM install.

For a manual install path, open Console in the live session and become root:

```sh
sudo su -
```

Partition and format the VM disk:

```sh
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart root ext4 512MB -8GB
parted /dev/vda -- mkpart swap linux-swap -8GB 100%
mkfs.ext4 -L nexos /dev/vda1
mkswap -L swap /dev/vda2
mount /dev/disk/by-label/nexos /mnt
swapon /dev/disk/by-label/swap
```

Generate hardware config and copy the starter Nexos config:

```sh
nex gen-config --root /mnt
cp -a /etc/nexos /mnt/etc/nexos
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nexos/hosts/vm/hardware.nix
rm -rf /mnt/etc/nixos
```

Install the system:

```sh
nex install --flake /mnt/etc/nexos#vm
```

Set the root password when prompted. The starter config also creates:

```text
user: nexos
password: password
```

Shut down the live ISO:

```sh
poweroff
```

## 6. Boot The Installed Nexos VM

Start the VM from the virtual disk, without the ISO:

```sh
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 2 \
  -drive file=nexos.qcow2,if=virtio,format=qcow2 \
  -display gtk
```

Log in as `nexos` with password `password`.

## 7. Use Nex As The Batteries-Included Interface

Inside the installed VM:

```sh
nex --help
nex doctor
nex version
nex info
```

Try the short OS commands:

```sh
nex build
sudo nex switch
```

Try package shell compatibility:

```sh
nex shell cmatrix
cmatrix
```

Try flake commands through the Nexos prefix:

```sh
nex flake --help
```

Try package builds through the Nexos prefix:

```sh
nex pkg build nixpkgs#hello
```

## 8. Shut Down

From inside the VM:

```sh
sudo poweroff
```

## Notes

- Before Nexos is installed, use `nix run "$NEXOS_SOURCE#nex" -- ...`
  or the temporary shell alias from step 1.
- After booting into a Nexos system, use `nex` directly.
- `nex build` is the OS build command. Use `nex pkg build` for package builds.
- `nex install` and `nex gen-config` wrap the compatible installer backends.
