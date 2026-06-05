{ config, inputs, ... }:
let
  hostname = "example";
  system = "x86_64-linux";
in
{
  flake.nexosConfigurations.${hostname} = inputs.nexos.lib.nexosSystem {
    inherit system;
    specialArgs = { inherit inputs; };
    modules = [
      ../../hosts/${hostname}/hardware.nix
      ../../hosts/${hostname}/default.nix
    ];
  };

  flake.nixosConfigurations.${hostname} =
    config.flake.nexosConfigurations.${hostname};

  perSystem =
    { system, ... }:
    if system == "x86_64-linux" then
      {
        packages.vm = config.flake.nexosConfigurations.${hostname}.config.system.build.vm;
      }
    else
      { };
}
