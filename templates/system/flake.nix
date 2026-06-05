{
  description = "Nexos system configuration";

  inputs = {
    # Bundled on the installer ISO at /etc/nexos/vendor/nexos for offline installs.
    # After install, switch to github with: sudo nex flake update nexos
    nexos.url = "path:./vendor/nexos";

    nexpkgs.follows = "nexos/nexpkgs";
    nixpkgs.follows = "nexpkgs";

    flake-parts.follows = "nexos/flake-parts";
    import-tree.follows = "nexos/import-tree";
  };

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
}
