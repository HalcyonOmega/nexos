{ inputs, self, ... }:

let
  installerHost = "nexos-installer";
in
{
  flake.nixosConfigurations.${installerHost} = self.lib.nexosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nexpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
      (
        { lib, pkgs, ... }:
        let
          nexPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.nex;
        in
        {
          networking.hostName = installerHost;

          image.baseName = lib.mkForce "nexos";
          isoImage.edition = lib.mkForce "gnome";
          isoImage.volumeID = "NEXOS_ISO";

          system.nixos = {
            distroId = "nexos";
            distroName = "NexOS";
          };

          users.users.nexos = {
            isNormalUser = true;
            extraGroups = [
              "wheel"
              "networkmanager"
              "video"
            ];
            initialPassword = "password";
          };

          nix.settings.trusted-users = [ "nexos" ];
          services.getty.autologinUser = lib.mkForce "nexos";
          services.displayManager.autoLogin.user = lib.mkForce "nexos";

          nexos = {
            release = "unstable";
            flakePath = "/etc/nexos";
          };

          nixpkgs.overlays = [
            (final: prev: {
              calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.python3 ];
                postInstall = (old.postInstall or "") + ''
                  python3 ${self}/scripts/patch-calamares-nixos.py "$out" \
                    "${nexPackage}" "${pkgs.nh}" \
                    "${pkgs.git}" "${pkgs.vim}" "${pkgs.helix}" "${pkgs.fastfetch}"
                '';
              });
            })
          ];

          environment.systemPackages = [
            pkgs.qemu
          ];

          environment.etc."nexos/flake.nix".text = ''
            {
              description = "Installed Nexos system";

              inputs = {
                nexos.url = "path:/etc/nexos/source";
                nexpkgs.follows = "nexos/nexpkgs";
                nixpkgs.follows = "nexpkgs";
              };

              outputs =
                { self, nexos, ... }@inputs:
                {
                  nexosConfigurations.vm = nexos.lib.nexosSystem {
                    system = "x86_64-linux";
                    specialArgs = { inherit inputs; };
                    modules = [
                      ./hardware-configuration.nix
                      ./configuration.nix
                    ];
                  };

                  nixosConfigurations.vm = self.nexosConfigurations.vm;
                };
            }
          '';

          environment.etc."nexos/source".source = self;

          environment.etc."nexos/configuration.nix".text = ''
            { lib, ... }:

            {
              networking.hostName = "nexos-vm";
              networking.networkmanager.enable = lib.mkDefault true;

              users.users.nexos = {
                isNormalUser = true;
                initialPassword = "password";
                extraGroups = [
                  "networkmanager"
                  "wheel"
                ];
              };

              nexos = {
                release = "unstable";
                # Exported as NEX_FLAKE for nex edit and other config-aware commands.
                flakePath = "/etc/nexos";
              };

              system.stateVersion = lib.mkDefault "25.05";
            }
          '';

          services.getty.helpLine = lib.mkForce ''
            The "nexos" account has password "password". The "root" account has an empty password.

            To log in over ssh you must set a password for "root"
            with `passwd` (prefix with `sudo` for "root"), or add your public key to
            /home/nexos/.ssh/authorized_keys or /root/.ssh/authorized_keys.

            To set up a wireless connection, run `nmtui`.

            Nexos installer

            Quick VM install:
              sudo su -
              parted /dev/vda -- mklabel gpt
              parted /dev/vda -- mkpart root ext4 512MB -8GB
              parted /dev/vda -- mkpart swap linux-swap -8GB 100%
              mkfs.ext4 -L nexos /dev/vda1
              mkswap -L swap /dev/vda2
              mount /dev/disk/by-label/nexos /mnt
              swapon /dev/disk/by-label/swap
              nex gen-config --root /mnt
              cp -RL /etc/nexos /mnt/etc/nexos
              cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nexos/hardware-configuration.nix
              nex install --flake /mnt/etc/nexos#vm

            After reboot, log in as nexos / password and run: nex --help
          '';
        }
      )
    ];
  };

  perSystem =
    { system, ... }:
    {
      packages = {
      }
      // (
        if system == "x86_64-linux" then
          {
            iso = self.nixosConfigurations.${installerHost}.config.system.build.isoImage;
          }
        else
          { }
      );
    };
}
