{
  flake.templates = {
    home = {
      path = ../../templates/home;
      description = "A minimal end-user Nexos host configuration";
    };

    system = {
      path = ../../templates/system;
      description = "The baseline Nexos system configuration installed to /etc/nexos";
    };

    default = {
      path = ../../templates/home;
      description = "A minimal end-user Nexos host configuration";
    };
  };
}
