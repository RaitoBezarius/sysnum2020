{ pkgs ? import <nixpkgs> {}, xlen ? 32, disableFloat ? true, disableAtomic ? true, arch ? "I" }:
let
  toolchain = import ./nix {
    inherit xlen disableFloat disableAtomic arch pkgs;
  };
in
pkgs.mkShell {
  buildInputs = toolchain;
}

