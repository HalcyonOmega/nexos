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
    # Exported as NEX_FLAKE for nex edit and other config-aware commands.
    flakePath = "/etc/nexos";
  };

  # Set this to the release used when the machine was first installed.
  system.stateVersion = lib.mkDefault "25.05";
}
