{
  description = "Nexos - an opinionated NixOS-compatible distribution";

  inputs = {
    
    nexpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.follows = "nexpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nexpkgs";

    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
}
