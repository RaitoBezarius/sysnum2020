{ libcxxStdenv, fetchgit }:

libcxxStdenv.mkDerivation rec {
    name = "riscv-tools";
    version = "2016.05.15";

    src = fetchgit {
        url = "https://github.com/riscv/riscv-tools";
        rev = "419f1b5f3ed7deefdf878b308119773b01d61084";
        sha256 = "1caqfc9l9z2i95c6d2m18sr31l9sflqf400jygy46y9sjrjcn2gf";
    };

    patches = [ ./riscv-fesvr-Add-missing-include2.patch ];

    prePatch = ''
        patchShebangs .
    '';

    buildPhase = ''
        export RISCV="$out"
        ./build-spike-only.sh
    '';

    installPhase = '':'';
}
