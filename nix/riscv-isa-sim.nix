{ libcxxStdenv, fetchFromGitHub, fesvr,
defaultISA ? "RV64IMAFDC" }:

libcxxStdenv.mkDerivation rec {
  name = "riscv-isa-sim";
  version = "2016.05.15";

  src = fetchFromGitHub {
    owner = "riscv";
    repo = "riscv-isa-sim";
    rev = "3bfc00ef2a1b1f0b0472a39a866261b00f67027e";
    sha256 = "0psikrlhxayrz7pimn9gvkqd5syvcm3l90hnwkgbd63nmv11fazi";
  };

  buildInputs = [ fesvr ];
  configureFlags = [ "--with-isa=${defaultISA}" ];
}
