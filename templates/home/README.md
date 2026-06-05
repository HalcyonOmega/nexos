# Nexos Host Template

Starting point for a personal Nexos configuration repository.

```sh
nex flake init -t github:halcyonomega/nexos#home
nex switch
```

## Layout

```text
flake.nix
modules/
  flake/
    systems.nix
    host.nix
hosts/
  example/
    default.nix       customize here
    hardware.nix        replace with `nex gen-config --show-hardware-config`
```

Same architecture as the `/etc/nexos` baseline installed from the Nexos ISO:
flake-parts, import-tree, and `nexos.lib.nexosSystem`.

## Commands

- `nex switch` and `nex build` for system lifecycle
- `nex shell cmatrix` for quick package shells
- `nex pkg build` for package builds
- `nex flake` for flake workflows
- `nex edit` to open the active config directory

The default system path is `/etc/nexos`, exported as `NEX_FLAKE` through
`nexos.flakePath`. Change that option when you want `nex` to target this
repository instead.

Before `nex` is installed system-wide:

```sh
nix run github:halcyonomega/nexos#nex -- --help
```
