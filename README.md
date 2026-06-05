# Nexos

Nexos is designed to be a modern, streamlined, easy-to-use, but opinionated NixOS-based distribution.

The current baseline intentionally keeps the Nix ecosystem compatible:

- Use `nex` as the batteries-included day-to-day command.
- Use `nix` directly only when you specifically need raw Nix behavior.
- Keep `.nix` files and the Nix store unchanged.
- Export both `nexosConfigurations` and `nixosConfigurations` while Nexos
  tooling matures.

## Current Command Surface

`nex` is a Rust CLI. For now it dispatches to the underlying tools:

| Command | Backend |
| --- | --- |
| `nex switch` | `nh os switch` |
| `nex boot` | `nh os boot` |
| `nex test` | `nh os test` |
| `nex build` | `nh os build` |
| `nex rollback` | `nh os rollback` |
| `nex info` / `nex list` | `nh os info` |
| `nex install` | `nixos-install` |
| `nex gen-config` | `nixos-generate-config` |
| `nex flake` | `nix flake` |
| `nex shell cowsay` | `nix-shell -p cowsay` |
| `nex shell .#dev` | `nix shell` |
| `nex develop` | `nix develop` |
| `nex pkg build` | `nix build` |
| `nex nix <cmd>` | `nix <cmd>` |
| `nex option` | `nixos-option` |
| `nex version` | `nixos-version` |
| `nex edit` | `$EDITOR` on the active config directory |
| unknown `nex <cmd>` | `nix <cmd>` |

Generic `nix` remains available for users who rely on it directly, but Nexos
docs should prefer `nex` wherever the behavior is intended to be branded and
ordinary.

## Installed System Baseline

The Nexos ISO installs a baseline flake to `/etc/nexos` (`templates/system`):

```text
/etc/nexos/
  flake.nix                 flake-parts + import-tree
  flake.lock                generated during install
  modules/flake/            host and platform definitions
  hosts/default/            customize default.nix; generated hardware/bootloader/installer modules
```

Nexos defaults (`nex`, `nh`, flakes, editor tools, `NEX_FLAKE`) come from
`github:halcyonomega/nexos` through `nexos.lib.nexosSystem`. After install:

```sh
nex edit
nex switch
```

For a from-scratch VM walkthrough, see [Run Nexos In A VM](docs/vm-guide.md).

## Personal Configuration

```sh
nex flake init -t github:halcyonomega/nexos#home
nex switch
```

The home template uses the same flake-parts + import-tree layout as the
installed baseline. Set `nexos.flakePath` to point `nex` at your personal repo
when you outgrow `/etc/nexos`.

## Development

```sh
nex flake check
nex pkg build .#nex
```

The flake supports `x86_64-linux` and `aarch64-linux`.
