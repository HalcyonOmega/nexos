{
  # Replace this file with the output of:
  #   nex gen-config --show-hardware-config
  imports = [ ];

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
  };
}
