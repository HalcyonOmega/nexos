{
  # Replace this file with the output of:
  #   nex gen-config --show-hardware-config
  imports = [ ];

  boot.loader.grub.devices = [ "nodev" ];

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
  };
}
