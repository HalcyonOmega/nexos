#!/usr/bin/env python3
"""Patch calamares-nixos-extensions to inject NexOS installer defaults."""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> None:
    out, nex_package, nh_package, git_package, vim_package, helix_package, fastfetch_package = (
        sys.argv[1:8]
    )
    path = Path(out) / "lib/calamares/modules/nixos/main.py"
    text = path.read_text()

    state_marker = '  system.stateVersion = "@@nixosversion@@"; # Did you read the comment?\n\n}\n'
    nexos_block = (
        '  system.stateVersion = "@@nixosversion@@"; # Did you read the comment?\n\n'
        "  # NexOS defaults.\n"
        '  nix.settings.experimental-features = [ "nix-command" "flakes" ];\n'
        '  nix.settings.trusted-users = [ "root" "@wheel" ];\n'
        "  system.nixos = {\n"
        '    distroId = "nexos";\n'
        '    distroName = "NexOS";\n'
        "  };\n"
        '  environment.etc."nexos-release".text = "NexOS unstable\\n";\n'
        '  environment.variables.NEX_FLAKE = "/etc/nexos";\n\n'
        "}\n"
    )

    pkgs_marker = (
        "  # List packages installed in system profile. To search, run:\n"
        "  # $ nix search wget\n"
        "  environment.systemPackages = with pkgs; [\n"
        "  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.\n"
        "  #  wget\n"
        "  ];\n\n"
    )
    pkgs_block = (
        "  # List packages installed in system profile. To search, run:\n"
        "  # $ nix search wget\n"
        "  environment.systemPackages = with pkgs; [\n"
        "  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.\n"
        "  #  wget\n"
        "  ] ++ [\n"
        f"    {nex_package}\n"
        f"    {nh_package}\n"
        f"    {git_package}\n"
        f"    {vim_package}\n"
        f"    {helix_package}\n"
        f"    {fastfetch_package}\n"
        "  ];\n\n"
    )

    if state_marker not in text:
        raise SystemExit("NexOS generated-config template marker not found")
    if pkgs_marker not in text:
        raise SystemExit("NexOS cfgpkgs template marker not found")

    text = text.replace(pkgs_marker, pkgs_block)
    text = text.replace(state_marker, nexos_block)
    path.write_text(text)


if __name__ == "__main__":
    main()
