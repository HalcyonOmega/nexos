# Nexos Host Template

This template is the starting point for an end-user Nexos configuration.

```sh
nex flake init -t github:halcyonomega/nexos#home
nex switch
```

Nexos keeps generic `nix` commands available, but day-to-day usage should go
through `nex`: `nex switch` and `nex build` for operating-system lifecycle,
`nex shell cmatrix` for quick package shells, `nex pkg build` for package
builds, and `nex flake` for flake workflows.

The default system path is `/etc/nexos`, exported as `NEX_FLAKE` through
`nexos.flakePath`. Change that option when you want `nex` to target a different
configuration directory by default.

Before `nex` is installed system-wide, bootstrap it once from the upstream flake:

```sh
nix run github:halcyonomega/nexos#nex -- --help
nix run github:halcyonomega/nexos#nex -- pkg build .#vm
```
