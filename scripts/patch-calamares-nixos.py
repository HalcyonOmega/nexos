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

    install_marker = (
        "    # Write the configuration.nix file\n"
        '    libcalamares.utils.host_env_process_output(["cp", "/dev/stdin", config], None, cfg)\n'
    )
    install_block = (
        "    # NexOS: install baseline flake config under /etc/nexos\n"
        '    nexos_live = "/etc/nexos"\n'
        "    if os.path.isdir(nexos_live):\n"
        "        libcalamares.utils.host_env_process_output(\n"
        '            ["cp", "-a", nexos_live, root_mount_point + "/etc/"], None\n'
        "        )\n"
        "        libcalamares.utils.host_env_process_output(\n"
        "            [\n"
        '                "cp",\n'
        '                root_mount_point + "/etc/nixos/hardware-configuration.nix",\n'
        '                root_mount_point + "/etc/nexos/hosts/vm/hardware.nix",\n'
        "            ],\n"
        "            None,\n"
        "        )\n"
        "        libcalamares.utils.host_env_process_output(\n"
        '            ["rm", "-rf", root_mount_point + "/etc/nixos"], None\n'
        "        )\n"
        "    else:\n"
        "        # Write the configuration.nix file\n"
        '        libcalamares.utils.host_env_process_output(["cp", "/dev/stdin", config], None, cfg)\n'
    )

    flake_install_marker = (
        "    nixosInstallCmd.extend(\n"
        "        [\n"
        '            "nixos-install",\n'
        '            "--no-root-passwd",\n'
        '            "--root",\n'
        "            root_mount_point,\n"
        '            "--log-format",\n'
        '            "internal-json",\n'
        "            # Nix requires its build directory to have no\n"
        "            # world-writable parent directories. The chroot store that\n"
        "            # nixos-install uses will use the state dir in the chroot\n"
        "            # for the build-dir, but the chroot is under /tmp, which\n"
        "            # is writable. It doesn't have to be in the chroot though,\n"
        "            # so we can just realign it with the host state dir.\n"
        '            "--option",\n'
        '            "build-dir",\n'
        '            "/nix/var/nix/builds",\n'
        "        ]\n"
        "    )\n"
    )
    flake_install_block = (
        "    nixos_install_args = [\n"
        '        "nixos-install",\n'
        '        "--no-root-passwd",\n'
        '        "--root",\n'
        "        root_mount_point,\n"
        '        "--log-format",\n'
        '        "internal-json",\n'
        "        # Nix requires its build directory to have no\n"
        "        # world-writable parent directories. The chroot store that\n"
        "        # nixos-install uses will use the state dir in the chroot\n"
        "        # for the build-dir, but the chroot is under /tmp, which\n"
        "        # is writable. It doesn't have to be in the chroot though,\n"
        "        # so we can just realign it with the host state dir.\n"
        '        "--option",\n'
        '        "build-dir",\n'
        '        "/nix/var/nix/builds",\n'
        "    ]\n"
        "    if os.path.isdir(nexos_live):\n"
        "        nixos_install_args[1:1] = [\n"
        '            "--flake",\n'
        '            root_mount_point + "/etc/nexos#vm",\n'
        "        ]\n"
        "    nixosInstallCmd.extend(nixos_install_args)\n"
    )

    if state_marker not in text:
        raise SystemExit("NexOS generated-config template marker not found")
    if pkgs_marker not in text:
        raise SystemExit("NexOS cfgpkgs template marker not found")
    if install_marker not in text:
        raise SystemExit("NexOS install hook marker not found")
    if flake_install_marker not in text:
        raise SystemExit("NexOS flake install marker not found")

    text = text.replace(pkgs_marker, pkgs_block)
    text = text.replace(state_marker, nexos_block)
    text = text.replace(install_marker, install_block)
    text = text.replace(flake_install_marker, flake_install_block)
    path.write_text(text)


if __name__ == "__main__":
    main()
