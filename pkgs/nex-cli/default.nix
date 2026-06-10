{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "nex";
  version = "0.2.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Nexos command-line interface";
    homepage = "https://github.com/halcyonomega/nexos";
    license = lib.licenses.mit;
    mainProgram = "nex";
    platforms = lib.platforms.linux;
  };
}
