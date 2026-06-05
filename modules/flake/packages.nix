{ self, ... }:

{
  perSystem =
    { pkgs, self', ... }:
    {
      packages = {
        nex = pkgs.callPackage ../../pkgs/nex-cli { };
        default = self'.packages.nex;
      };

      apps = {
        nex = {
          type = "app";
          program = "${self'.packages.nex}/bin/nex";
          meta.description = "Run the Nexos CLI";
        };
        default = self'.apps.nex;
      };

      checks.nex-cli = self'.packages.nex;
    };

  flake.overlays.default = final: _prev: {
    nex = self.packages.${final.stdenv.hostPlatform.system}.nex;
  };
}
