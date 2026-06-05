{
  description = "My Nexos system";

  inputs = {
    nexos.url = "github:halcyonomega/nexos";

    # User-facing package foundation. Nexos currently follows upstream nixpkgs,
    # but keeping this name makes future nexpkgs migration explicit.
    nexpkgs.follows = "nexos/nexpkgs";
    nixpkgs.follows = "nexpkgs";
  };

  outputs =
    {
      self,
      nexos,
      ...
    }@inputs:
    let
      hostname = "example";
      system = "x86_64-linux";
    in
    {
      nexosConfigurations.${hostname} = nexos.lib.nexosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${hostname}/hardware.nix
          ./hosts/${hostname}/default.nix
        ];
      };

      # Compatibility alias for NixOS ecosystem tools while Nexos tooling matures.
      nixosConfigurations.${hostname} = self.nexosConfigurations.${hostname};

      packages.${system}.vm = self.nexosConfigurations.${hostname}.config.system.build.vm;
    };
}
