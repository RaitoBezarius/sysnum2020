{ stdenv, pkgs, fetchFromGitHub,
xlen ? 64, arch ? "IMAFD", newlibCflags ? "",
enableLinux ? false, enableMultilib ? false,
disableFloat ? false, disableAtomic ? false }:

stdenv.mkDerivation rec {
  name = "riscv-toolchain";

  src = fetchFromGitHub {
    owner = "riscv";
    repo = "riscv-gnu-toolchain";
    rev = "ed53ae7a71dfc6df1940c2255aea5bf542a9c422";
    sha256 = "148iaji3xqlnsqbayh1z6jybz7dmwjq0fw0bgm6md48mrziwjapg";
    fetchSubmodules = true;
  }

  buildInputs = with pkgs; [ autoconf automake texinfo
  gmp libmpc mpfr gawk bison flex texinfo gperf curl ];

  configureFlags = [
    "--with-xlen=${toString xlen}"
    "--with-arch=${arch}"
    (if enableLinux then "--enable-linux" else "")
    (if enableMultilib then "--enable-multilib" else "")
    (if disableFloat then "--disable-float" else "")
    (if disableAtomic then "--disable-atomic" else "")
    ];

    CFLAGS_FOR_TARGET = newlibCflags;

    dontPatchELF = true;
    dontStrip = true;
  }
