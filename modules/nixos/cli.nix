{ self, ... }:

{
  flake.nixosModules.cli =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nexos.cli;
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      options.nexos.cli = {
        enable = lib.mkEnableOption "the nex command-line interface";

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${system}.nex;
          defaultText = lib.literalExpression "nexos.packages.\${pkgs.stdenv.hostPlatform.system}.nex";
          description = "The nex CLI package to install.";
        };

        backend = lib.mkOption {
          type = lib.types.enum [ "nh" ];
          default = "nh";
          description = "Backend used by nex for system lifecycle commands.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          cfg.package
          pkgs.nh
        ];

        programs.nh = {
          enable = lib.mkDefault true;
          flake = lib.mkDefault config.nexos.flakePath;
        };
      };
    };
}
