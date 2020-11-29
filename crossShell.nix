with import <nixpkgs> {
  crossSystem = (import <nixpkgs/lib>).systems.examples.riscv32-embedded;
};

mkShell {
  buildInputs = [ zlib ]; # your dependencies here
}
