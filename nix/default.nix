{ pkgs, xlen, disableFloat, disableAtomic, arch }:
let riscvPkgs = import ./top-level.nix {
  inherit pkgs;
};
  toolchain = riscvPkgs.riscv-toolchain.override {
      inherit xlen disableFloat disableAtomic arch;
      newlibCflags = [
        "-g" "-Os"
        "-DINTEGER_ONLY"
        "-DPREFER_SIZE_OVER_SPEED"
        "-DREENTRANT_SYSCALLS_PROVIDED"
        "-fomit-frame-pointer"
      ];
    };
  spike = riscvPkgs.spike.override {
    defaultISA = "RV${toString xlen}${arch}";
  };
  pk = riscvPkgs.pk.override {
    riscv-toolchain = toolchain;
    inherit xlen spike;
  };
  # gdb = riscvPkgs.riscv-gdb.override { inherit xlen; };
in
  [
    toolchain
    spike
    pk
    # gdb
  ]

