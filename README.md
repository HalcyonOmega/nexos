# Nexos

Nexos is an opinionated, NixOS-compatible distribution built on a package
foundation exposed as `nexpkgs`.

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

## End-User Template

```sh
nex flake init -t github:halcyonomega/nexos#home
nex switch
```

The template uses:

- `inputs.nexos.url = "github:halcyonomega/nexos"`
- `inputs.nexpkgs.follows = "nexos/nexpkgs"`
- `nexos.lib.nexosSystem`
- `nexosConfigurations.<hostname>`
- a compatibility alias at `nixosConfigurations.<hostname>`

For a from-scratch VM walkthrough, see [Run Nexos In A VM](docs/vm-guide.md).

## Config Path Tradeoffs

There are three reasonable defaults:

| Path model | Strengths | Weaknesses |
| --- | --- | --- |
| `/etc/nexos` only | Strongest distro identity, simple installer story, clean docs | Less flexible for users who prefer personal git repos |
| `~/nexos-config` only | Great for users, no root-owned lockfiles, easy Git workflow | Weaker appliance/installer story; more user-specific setup |
| Both, with `NEX_FLAKE` | Best compatibility and migration path; supports installer and personal repos | Slightly more documentation and CLI resolution logic |

This scaffold uses the third model. `/etc/nexos` is the default, exported as
`NEX_FLAKE` via `nexos.flakePath`, and users can change that option to target a
personal configuration repository.

## Development

```sh
nex flake check
nex pkg build .#nex
```

The flake supports `x86_64-linux` and `aarch64-linux`.
