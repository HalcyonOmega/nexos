{
  flake.nixosModules.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nexos;
    in
    {
      options.nexos = {
        enable = lib.mkEnableOption "Nexos defaults";

        flakePath = lib.mkOption {
          type = lib.types.str;
          default = "/etc/nexos#default";
          description = "Default flake reference used by Nexos system commands.";
        };

        release = lib.mkOption {
          type = lib.types.str;
          default = "unstable";
          description = "Nexos release identifier exposed to users.";
        };
      };

      config = lib.mkIf cfg.enable {
        nix.settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            "@wheel"
          ];
        };

        environment.etc."nexos-release".text = "Nexos ${cfg.release}\n";

        environment.sessionVariables = {
          NEX_FLAKE = cfg.flakePath;
        };

        boot.loader.limine.enable = lib.mkDefault true;

        environment.systemPackages = with pkgs; [
          git
          vim
          helix
          fastfetch
        ];

        system.activationScripts.removeLegacyNixosConfig = {
          text = ''
            if [ -e /etc/nexos/flake.nix ] && [ -e /etc/nixos ]; then
              rm -rf /etc/nixos
            fi
          '';
        };
      };
    };
}
