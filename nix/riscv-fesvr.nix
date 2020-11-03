{ libcxxStdenv, fetchFromGitHub }:

libcxxStdenv.mkDerivation rec {
    name = "riscv-fesvr";
    version = "2016.05.15";

    src = fetchFromGitHub {
        owner = "riscv";
        repo = "riscv-fesvr";
        rev = "916191caf38dbaffd3144de6bf0103eff5529ace";
        sha256 = "1pk0x6bag04cdm5rczfgixl5mh76dd1rl8w7k27h4fkbc3pm0004";
    };
}
