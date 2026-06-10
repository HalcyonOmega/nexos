{ lib, ... }:

let
  hasInstallerConfig = builtins.pathExists ./installer.nix;
in

{
  imports = lib.optional hasInstallerConfig ./installer.nix;

  networking.hostName = lib.mkDefault "nexos";
  networking.networkmanager.enable = lib.mkDefault true;

  users.users.nexos = lib.mkIf (!hasInstallerConfig) {
    isNormalUser = true;
    initialPassword = "password";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  services.xserver.enable = lib.mkDefault true;
  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;

  nexos = {
    release = "unstable";
    flakePath = "/etc/nexos#default";
  };

  system.stateVersion = lib.mkDefault "25.05";
}
