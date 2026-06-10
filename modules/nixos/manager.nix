{ self, ... }:

{
  flake.nixosModules.manager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nexos.manager;
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      options.nexos.manager = {
        enable = lib.mkEnableOption "the Nexos graphical manager";

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${system}.nexos-manager;
          defaultText = lib.literalExpression "nexos.packages.\${pkgs.stdenv.hostPlatform.system}.nexos-manager";
          description = "The Nexos graphical manager package to install.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          cfg.package
        ];
      };
    };
}
