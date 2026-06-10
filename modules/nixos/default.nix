{ self, ... }:

{
  flake.nixosModules.default =
    { lib, ... }:
    {
      imports = [
        self.nixosModules.base
        self.nixosModules.cli
        self.nixosModules.manager
      ];

      nexos.enable = lib.mkDefault true;
      nexos.cli.enable = lib.mkDefault true;
      nexos.manager.enable = lib.mkDefault true;
    };
}
