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
          nexosVendor = lib.cleanSource self;
          nexosEtc = pkgs.runCommand "nexos-etc" { } ''
            mkdir -p $out/vendor
            cp -r ${self}/templates/system/. $out/
            cp -r ${nexosVendor} $out/vendor/nexos
          '';
          nexosInstallWrapper = pkgs.writeShellApplication {
            name = "nixos-install";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.findutils
              pkgs.gnused
              pkgs.nixos-install-tools
              pkgs.util-linux
            ];
            text = ''
              root=""
              args=("$@")

              for ((i = 0; i < ''${#args[@]}; i++)); do
                if [[ "''${args[$i]}" == "--root" && $((i + 1)) -lt ''${#args[@]} ]]; then
                  root="''${args[$((i + 1))]}"
                  break
                fi
              done

              if [[ -n "$root" && -d /etc/nexos && ! " ''${args[*]} " =~ " --flake " ]]; then
                rm -rf "$root/etc/nexos"
                mkdir -p "$root/etc/nexos"
                cp -aL /etc/nexos/. "$root/etc/nexos/"

                if [[ -f "$root/etc/nixos/hardware-configuration.nix" ]]; then
                  mkdir -p "$root/etc/nexos/hosts/default"
                  cp "$root/etc/nixos/hardware-configuration.nix" "$root/etc/nexos/hosts/default/hardware.nix"
                fi

                root_source="$(findmnt --noheadings --output SOURCE --target "$root" | sed -n '1p' || true)"
                root_device="$(readlink -f "$root_source" || true)"
                boot_device=""
                if [[ -n "$root_device" && -b "$root_device" ]]; then
                  parent_name="$(lsblk --noheadings --output PKNAME "$root_device" | sed -n '1p' || true)"
                  if [[ -n "$parent_name" ]]; then
                    boot_device="/dev/$parent_name"
                  else
                    boot_device="$root_device"
                  fi
                fi

                if [[ -n "$boot_device" ]]; then
                  cat > "$root/etc/nexos/hosts/default/bootloader.nix" <<EOF
{ lib, ... }:

{
  boot.loader.limine.efiSupport = false;
  boot.loader.limine.biosSupport = true;
  boot.loader.limine.biosDevice = lib.mkDefault "$boot_device";
}
EOF
                elif [[ ! -d /sys/firmware/efi ]]; then
                  echo "nexos-install: unable to determine BIOS boot disk from mounted root '$root'" >&2
                  exit 1
                fi

                rm -f "$root/etc/nexos/flake.lock"
                rm -rf "$root/etc/nixos"
                args=("--flake" "$root/etc/nexos#default" "--no-write-lock-file" "''${args[@]}")
              fi

              exec ${pkgs.nixos-install-tools}/bin/nixos-install "''${args[@]}"
            '';
          };
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

          environment.systemPackages = [
            (lib.hiPrio nexosInstallWrapper)
            nexPackage
            pkgs.nh
            pkgs.git
            pkgs.vim
            pkgs.helix
            pkgs.fastfetch
            pkgs.qemu
          ];

          nixpkgs.overlays = [
            (final: prev: {
              calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.python3 ];
                postInstall = (old.postInstall or "") + ''
                  sed -i '/^  - users$/d' "$out/etc/calamares/settings.conf"
                  python3 - "$out/etc/calamares/modules/partition.conf" <<'PY'
                  import pathlib
                  import sys

                  path = pathlib.Path(sys.argv[1])
                  text = path.read_text()

                  if "    - fat32\n" not in text:
                      text = text.replace(
                          "availableFileSystemTypes:\n",
                          "availableFileSystemTypes:\n    - fat32\n",
                          1,
                      )

                  boot_partition = "".join([
                      '    - name: "boot"\n',
                      '      filesystem: "fat32"\n',
                      '      noEncrypt: true\n',
                      '      mountPoint: "/boot"\n',
                      '      size: 1GiB\n',
                  ])

                  if 'name: "boot"' not in text:
                      text = text.replace("partitionLayout:\n", "partitionLayout:\n" + boot_partition, 1)

                  path.write_text(text)
                  PY
                '';
              });
            })
          ];

          environment.etc."nexos".source = nexosEtc;

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
              rm -rf /mnt/etc/nexos
              cp -a /etc/nexos /mnt/etc/nexos
              mkdir -p /mnt/etc/nexos/hosts/default
              cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nexos/hosts/default/hardware.nix
              root_device=$(readlink -f "$(findmnt --noheadings --output SOURCE --target /mnt | sed -n '1p')")
              boot_parent=$(lsblk --noheadings --output PKNAME "$root_device" | sed -n '1p')
              boot_device="$root_device"
              if [ -n "$boot_parent" ]; then boot_device="/dev/$boot_parent"; fi
              printf '{ lib, ... }: { boot.loader.limine.efiSupport = false; boot.loader.limine.biosSupport = true; boot.loader.limine.biosDevice = lib.mkDefault "%s"; }\n' "$boot_device" > /mnt/etc/nexos/hosts/default/bootloader.nix
              rm -rf /mnt/etc/nixos
              nex install --flake /mnt/etc/nexos#default --no-write-lock-file

            After reboot, log in as nexos / password and run: nex --help
          '';
        }
      )
    ];
  };

  perSystem =
    { system, ... }:
    {
      packages = { }
        // (
          if system == "x86_64-linux" then
            {
              iso = self.nixosConfigurations.${installerHost}.config.system.build.isoImage;
            }
          else
            { }
        );

      checks = { }
        // (
          if system == "x86_64-linux" then
            {
              system-template-default =
                (self.lib.nexosSystem {
                  inherit system;
                  modules = [
                    (
                      { config, ... }:
                      {
                        assertions = [
                          {
                            assertion = config.boot.loader.limine.biosDevice != "nodev";
                            message = "The default installed system must set a real Limine BIOS boot device.";
                          }
                        ];
                      }
                    )
                    (
                      { ... }:
                      {
                        fileSystems."/" = {
                          device = "/dev/vda1";
                          fsType = "ext4";
                        };

                        boot.loader.limine.biosDevice = "/dev/vda";
                        boot.loader.limine.efiSupport = false;
                        boot.loader.limine.biosSupport = true;
                      }
                    )
                    ../../templates/system/hosts/default/default.nix
                  ];
                }).config.system.build.toplevel;
            }
          else
            { }
        );
    };
}
