{lib, ...}: {
  flake-file.inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
  };
  systems = lib.mkDefault lib.systems.flakeExposed;
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    devShells.default = lib.mkDefault (pkgs.mkShell {
      buildInputs = with pkgs.buildPackages; [
        openssl
        pkg-config

        # libs
        udev

        libinput
        libxkbcommon

        (rust-bin.fromRustupToolchainFile ../../rust-toolchain.toml)
        # rust-analyzer
      ];
    });
  };
}
