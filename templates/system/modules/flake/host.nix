{ config, inputs, ... }:
let
  hostname = "default";
  system = "x86_64-linux";
in
{
  flake.nexosConfigurations.${hostname} = inputs.nexos.lib.nexosSystem {
    inherit system;
    specialArgs = { inherit inputs; };
    modules = [
      ../../hosts/${hostname}/hardware.nix
      ../../hosts/${hostname}/bootloader.nix
      ../../hosts/${hostname}/default.nix
    ];
  };

  flake.nixosConfigurations.${hostname} =
    config.flake.nexosConfigurations.${hostname};
}
