{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.writeShellApplication {
        name = "nexos-fmt";
        runtimeInputs = [
          pkgs.findutils
          pkgs.nixfmt
        ];
        text = ''
          find . -name '*.nix' \
            -not -path './result*' \
            -not -path './.git/*' \
            -print0 | xargs -0 nixfmt
        '';
      };
    };
}
