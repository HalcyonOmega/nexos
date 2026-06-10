{
  lib,
  rustPlatform,
  makeWrapper,
  pkg-config,
  fontconfig,
  libGL,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libxkbcommon,
  wayland,
  nex,
  nh,
  nix,
  xdg-utils,
}:

rustPlatform.buildRustPackage {
  pname = "nexos-manager";
  version = "0.2.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    fontconfig
    libGL
    libX11
    libXcursor
    libXi
    libXrandr
    libxkbcommon
    wayland
  ];

  postInstall = ''
    wrapProgram "$out/bin/nexos-manager" \
      --prefix PATH : ${
        lib.makeBinPath [
          nex
          nh
          nix
          xdg-utils
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${
        # winit/glutin load these via dlopen at runtime, so linking alone
        # is not enough; without this the app aborts with
        # "Failed to initialize any backend" outside of a matching profile.
        lib.makeLibraryPath [
          fontconfig
          libGL
          libX11
          libXcursor
          libXi
          libXrandr
          libxkbcommon
          wayland
        ]
      }

    install -Dm644 ${./nexos-manager.desktop} \
      "$out/share/applications/nexos-manager.desktop"
  '';

  meta = {
    description = "Graphical Nexos manager";
    homepage = "https://github.com/halcyonomega/nexos";
    license = lib.licenses.mit;
    mainProgram = "nexos-manager";
    platforms = lib.platforms.linux;
  };
}
