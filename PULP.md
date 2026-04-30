Make sure you cloned the repo with all its submodules. If you haven't, do it by:
```
git submodule update --init --recursive
```

Generate tablegen files for PULP extensions from the specifications in the submoduled `riscv-opcodes` repo using:
```
./generate-pulp-td.sh
```
All generated files are tracked, so differences can be viewed with git.

Build the toolchain by running:
```
.github/pulp/scripts/build-riscv32-llvm.sh
```
Your mileage may vary here, but a quick LLM search should be able to help you figure out any errors. Also, the CI runs the same script, so you may use that as reference.