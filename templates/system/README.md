# Nexos System Baseline

Default configuration installed to `/etc/nexos` on Nexos systems.

## Layout

```text
/etc/nexos/
  flake.nix                 flake-parts + import-tree
  modules/
    flake/
      systems.nix           supported platforms
      host.nix              defines the default host
  hosts/
    default/
      default.nix             customize the system here
      hardware.nix            generated at install time
      bootloader.nix          generated at install time
```

Nexos defaults (`nex`, `nh`, flakes, packages, `NEX_FLAKE`) come from the
bundled `vendor/nexos` input through `nexos.lib.nexosSystem`. After install,
point the flake at GitHub with `sudo nex flake update nexos`.

## Day to day

```sh
sudo nex edit
sudo nex switch
```

## Update Nexos

```sh
cd /etc/nexos
sudo nex flake update nexos
sudo nex switch
```

## Customize further

- Edit `hosts/default/default.nix` for hostname, users, and services.
- Add modules under `modules/` to grow the flake with import-tree.
- Change `hostname` in `modules/flake/host.nix` if you rename the host.
