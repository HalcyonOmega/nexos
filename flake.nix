{
  description = "Nexos - an opinionated NixOS-compatible distribution";

  inputs = {
    # The public foundation for Nexos. This currently points at upstream nixpkgs;
    # later it can move to a dedicated nexpkgs fork without changing user-facing
    # templates.
    nexpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Compatibility alias for tools and modules that expect an input named nixpkgs.
    nixpkgs.follows = "nexpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nexpkgs";

    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
}
