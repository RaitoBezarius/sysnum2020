{ stdenv, fetchFromGitHub, overrideCC, riscv-toolchain, spike, xlen ? 64 }:

let
    stdenvRiscv = overrideCC stdenv riscv-toolchain;
in
stdenvRiscv.mkDerivation rec {
    name = "riscv-pk";
    version = "2016.05.15";

    src = fetchFromGitHub {
        owner = "riscv";
        repo = "riscv-pk";
        rev = "1bcab7872c6ae98ab86cdc1a3f567fd263e723d7";
        sha256 = "01rqb74mhxzwv9k73zcpbdlkxk6svrbm2cspkcpb8204kgcgdk7f";
    };

    nativeBuildInputs = [ riscv-toolchain spike ];

    configureFlags = [ "--host=riscv${toString xlen}-unknown-elf" ];
    configurePhase = ''
        mkdir build
        cd build
        ../configure -prefix $out $configureFlags
    '';

    dontPatchELF = true;
    dontStrip = true;
}
