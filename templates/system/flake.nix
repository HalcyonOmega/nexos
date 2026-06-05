{
  description = "Nexos system configuration";

  inputs = {
    nexos.url = "github:halcyonomega/nexos";

    nexpkgs.follows = "nexos/nexpkgs";
    nixpkgs.follows = "nexpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nexpkgs";

    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
}
