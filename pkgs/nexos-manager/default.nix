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
  version = "0.1.0";

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
      }
  '';

  meta = {
    description = "Graphical Nexos manager";
    homepage = "https://github.com/halcyonomega/nexos";
    license = lib.licenses.mit;
    mainProgram = "nexos-manager";
    platforms = lib.platforms.linux;
  };
}
