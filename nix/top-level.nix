{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:
let
  callPackage = lib.callPackageWith (pkgs // self);
  self = rec {
    fesvr = callPackage ./riscv-fesvr.nix {};
    spike = callPackage ./riscv-isa-sim.nix {};
    riscv-gdb = callPackage ./riscv-gdb.nix {};
    pk = callPackage ./riscv-pk.nix {};
    riscv-tools = callPackage ./riscv-tools.nix {};
    riscv-toolchain = callPackage ./riscv-toolchain.nix {};
  };
in
  self
