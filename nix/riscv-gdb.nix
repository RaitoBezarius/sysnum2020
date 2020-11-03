{ fetchurl, stdenv, ncurses, readline, gmp, mpfr, expat, texinfo, zlib
, dejagnu, perl, pkgconfig, bison, flex, fetchFromGitHub
, python ? null
, guile ? null
, target ? null
# Support all known targets in one gdb binary.
, multitarget ? false
# Additional dependencies for GNU/Hurd.
, mig ? null, hurd ? null
, xlen ? 64
}:

let

  basename = "gdb-7.11";

  # Whether (cross-)building for GNU/Hurd.  This is an approximation since
  # having `stdenv ? cross' doesn't tell us if we're building `crossDrv' and
  # `nativeDrv'.
  isGNU =
      stdenv.system == "i686-gnu"
      || (stdenv ? cross && stdenv.cross.config == "i586-pc-gnu");

in

assert isGNU -> mig != null && hurd != null;

stdenv.mkDerivation rec {
  name = "riscv-gdb";
  version = "2016.05.15";

  src = fetchFromGitHub {
      owner = "riscv";
      repo = "riscv-binutils-gdb";
      rev = "2a3cd80468d00f13d4557401aa4c92100abf0cd3";
      sha256 = "1zx5rgy3hrahrs74ypzdwxz6ix0j8qzr7bybwybir4l7b7v8yyqb";
  };

  nativeBuildInputs = [ pkgconfig texinfo perl ];
    #++ stdenv.lib.optional isGNU mig;

  buildInputs = [ ncurses readline gmp mpfr expat zlib python guile bison flex ]
  #  ++ stdenv.lib.optional isGNU hurd
    ++ stdenv.lib.optional doCheck dejagnu;

  enableParallelBuilding = false;

  configureFlags = [ "--with-gmp=${gmp}" "--with-mpfr=${mpfr}" "--with-system-readline"
      "--with-system-zlib" "--with-expat" "--with-libexpat-prefix=${expat}"
      "--with-separate-debug-dir=/run/current-system/sw/lib/debug"
      "--target=riscv${toString xlen}-unknown-elf"];

  crossAttrs = {
    configureFlags = ["--target=riscv${toString xlen}-unknown-elf"];
  };

  # TODO: Investigate & fix the test failures.
  doCheck = false;

  meta = with stdenv.lib; {
    description = "The GNU Project debugger";

    longDescription = ''
      GDB, the GNU Project debugger, allows you to see what is going
      on `inside' another program while it executes -- or what another
      program was doing at the moment it crashed.
    '';

    homepage = http://www.gnu.org/software/gdb/;

    license = stdenv.lib.licenses.gpl3Plus;

    platforms = with platforms; linux ++ cygwin ++ darwin;
    maintainers = with maintainers; [ pierron ];
  };
}
