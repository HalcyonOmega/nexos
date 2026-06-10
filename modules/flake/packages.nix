{ self, ... }:

{
  perSystem =
    { pkgs, self', ... }:
    {
      packages = {
        nex = pkgs.callPackage ../../pkgs/nex-cli { };
        nexos-manager = pkgs.callPackage ../../pkgs/nexos-manager {
          nex = self'.packages.nex;
        };
        default = self'.packages.nex;
      };

      apps = {
        nex = {
          type = "app";
          program = "${self'.packages.nex}/bin/nex";
          meta.description = "Run the Nexos CLI";
        };
        nexos-manager = {
          type = "app";
          program = "${self'.packages.nexos-manager}/bin/nexos-manager";
          meta.description = "Run the Nexos graphical manager";
        };
        default = self'.apps.nex;
      };

      checks.nex-cli = self'.packages.nex;
      checks.nexos-manager = self'.packages.nexos-manager;
    };

  flake.overlays.default = final: _prev: {
    nex = self.packages.${final.stdenv.hostPlatform.system}.nex;
    nexos-manager = self.packages.${final.stdenv.hostPlatform.system}.nexos-manager;
  };
}
