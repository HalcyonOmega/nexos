{ lib, ... }:

{
  networking.hostName = "example";
  networking.networkmanager.enable = lib.mkDefault true;

  users.users.nexos = {
    isNormalUser = true;
    initialPassword = "password";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  nexos = {
    release = "unstable";
    flakePath = "/etc/nexos#example";
  };

  system.stateVersion = lib.mkDefault "25.05";
}
