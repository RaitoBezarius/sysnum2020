with import <nixpkgs> {
  crossSystem = (import <nixpkgs/lib>).systems.examples.riscv32-embedded // {
    platform = {
      name = "riscv-soft-float-multiplatform";
      kernelArch = "risc";
      kernelTarget = "vmlinux";
      bfdEmulation = "elf32lriscv";
      gcc.arch = "rv32im";
    };
  };
};

let
  hostNixpkgs = import <nixpkgs> {};
  elf2hex = hostNixpkgs.stdenv.mkDerivation {
    pname = "elf2hex";
    version = "1.0.1";
    depsBuildBuild = [ stdenv.cc ];
    buildInputs = [ hostNixpkgs.python3 ];
    configureFlags = "--target=riscv32-none-elf";
    src = fetchurl {
      url = "https://github.com/sifive/elf2hex/releases/download/v1.0.1/elf2hex-1.0.1.tar.gz";
      sha256 = "1c65vzh2173xh8a707g17qgss4m5zp3i5czxfv55349102vyqany";
    };
  };
in
  mkShell {
    name = "riscv-toolchain-shell";
    nativeBuildInputs = [ elf2hex hostNixpkgs.symbiyosys hostNixpkgs.verilator ];
  }

