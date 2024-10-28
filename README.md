# Assemble test file

## Generate bin file

```console
./assembler/as65.exe ./src/tests/6502_functional_test.a65 -x1 -n -l./src/tests/6502_functional_test.lst -o./src/tests/6502_functional_test.bin -w -h0 -m -v
```

## Generate hex file

```console
./assembler/as65.exe ./src/tests/6502_functional_test.a65 -x1 -n -l./src/tests/6502_functional_test.lst -o./src/tests/6502_functional_test.hex -s2 -w -h0 -m -v
```
