## Nix scripts for RISC-V toolchain

Taken from <https://github.com/dvc94ch/riscv-nix/>

# Getting started

1. Install the Nix package manager: <https://nixos.org/download.html>
2. Run `nix-shell -f shell.nix` at the root of the project.
3. Enjoy your RISC-V toolchain.

# Tweaking with the stuff

If you want to change `xlen` or run a different toolchain, for example, for RV64I or atomic support, etc.

You will have to run `nix-shell -f shell.nix --arg xlen 64 --arg disableAtomic false --arg disableFloat false --argstr arch IM` which will give you a RV64IMA with floating support.

Everything won't work out of the box, when in doubt, ping Ryan.
