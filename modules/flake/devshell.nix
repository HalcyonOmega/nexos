{ self, ... }:

{
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          self'.packages.nex
          self'.packages.nexos-manager
          pkgs.deadnix
          pkgs.nh
          pkgs.nil
          pkgs.nixd
          pkgs.nixfmt
        ];

        shellHook = ''
          export NEX_FLAKE="$PWD"
          echo "Nexos dev shell - use: nex switch --dry"
        '';
      };
    };
}
