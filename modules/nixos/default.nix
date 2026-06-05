{ self, ... }:

{
  flake.nixosModules.default =
    { lib, ... }:
    {
      imports = [
        self.nixosModules.base
        self.nixosModules.cli
      ];

      nexos.enable = lib.mkDefault true;
      nexos.cli.enable = lib.mkDefault true;
    };
}
