{ inputs, self, ... }:

let
  lib = inputs.nexpkgs.lib;
in
{
  flake.lib = {
    inherit lib;

    nexosSystem =
      {
        modules ? [ ],
        specialArgs ? { },
        ...
      }@args:
      lib.nixosSystem (
        (builtins.removeAttrs args [
          "modules"
          "specialArgs"
        ])
        // {
          specialArgs = specialArgs // {
            inherit inputs self;
            nexos = self;
          };

          modules = [
            self.nixosModules.default
          ]
          ++ modules;
        }
      );
  };
}
