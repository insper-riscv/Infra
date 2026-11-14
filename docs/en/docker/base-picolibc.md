# base-picolibc

`ghcr.io/<organization>/base-picolibc` and `ghcr.io/<organization>/base-picolibc-rv64` hold the files picolibc and libstdc++ install into the GCC's sysroot, under `/opt/riscv-foundation/riscv32-elf`, the first for the 32-bit variants and the second for the 64-bit ones. They are compiled with [`base-gcc`](base-gcc.md), and [`ci-elf`](ci-elf.md) copies both over the GCC's prefix. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| picolibc | the C library compiled by the GCC of the latest `base-gcc`, installed into the sysroot, once for each of the 192 variants of the width of the image (section 2.1) |
| `libsupc++` and `libstdc++` | the C++ libraries of the same GCC, built against the installed picolibc, for the same variants (section 4), and the C++ headers in `riscv32-unknown-elf/include/c++/<GCC version>` |

The file `/opt/riscv-foundation/riscv32-elf/.picolibc.tag` (`.picolibc-rv64.tag` in the 64-bit image) has two lines. The first is the picolibc commit, and the second is the version, the date of the commit, the short commit, the number of library variants of the image and the libstdc++ version (`1.8.12 2026-07-30 (2ae376c), 192 variants, libstdc++ 16.1.0`).

picolibc is compiled by a cross compiler, so the build uses the latest GCC image. The image carries the commit of that GCC in the label `riscv-gnu-toolchain.commit`, and a new GCC makes a new picolibc build.

## 2. Variants

### 2.1. What runs in hardware and what in software

Every row is a combination of base, multiply and floating point, built in eight versions (section 2.2), and each version is one library installed into the sysroot. An operation marked software is a call to a routine of `libgcc` (for example `__mulsi3`, `__divsi3`, `__addsf3` and `__adddf3`), so a core without the extension still runs the program, only slower.

| `-march` | `-mabi` | Integer registers | Multiply | Divide | Single precision (`float`) | Double precision (`double`) |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `rv32i` (default) | `ilp32` | 32 | software | software | software | software |
| `rv32if` | `ilp32` | 32 | software | software | hardware | software |
| `rv32if` | `ilp32f` | 32 | software | software | hardware | software |
| `rv32ifd` | `ilp32` | 32 | software | software | hardware | hardware |
| `rv32ifd` | `ilp32f` | 32 | software | software | hardware | hardware |
| `rv32ifd` | `ilp32d` | 32 | software | software | hardware | hardware |
| `rv32i_zmmul` | `ilp32` | 32 | hardware | software | software | software |
| `rv32if_zmmul` | `ilp32` | 32 | hardware | software | hardware | software |
| `rv32if_zmmul` | `ilp32f` | 32 | hardware | software | hardware | software |
| `rv32ifd_zmmul` | `ilp32` | 32 | hardware | software | hardware | hardware |
| `rv32ifd_zmmul` | `ilp32f` | 32 | hardware | software | hardware | hardware |
| `rv32ifd_zmmul` | `ilp32d` | 32 | hardware | software | hardware | hardware |
| `rv32im` | `ilp32` | 32 | hardware | hardware | software | software |
| `rv32imf` | `ilp32` | 32 | hardware | hardware | hardware | software |
| `rv32imf` | `ilp32f` | 32 | hardware | hardware | hardware | software |
| `rv32imfd` | `ilp32` | 32 | hardware | hardware | hardware | hardware |
| `rv32imfd` | `ilp32f` | 32 | hardware | hardware | hardware | hardware |
| `rv32imfd` | `ilp32d` | 32 | hardware | hardware | hardware | hardware |
| `rv32e` | `ilp32e` | 16 | software | software | software | software |
| `rv32ef` | `ilp32e` | 16 | software | software | hardware | software |
| `rv32e_zmmul` | `ilp32e` | 16 | hardware | software | software | software |
| `rv32ef_zmmul` | `ilp32e` | 16 | hardware | software | hardware | software |
| `rv32em` | `ilp32e` | 16 | hardware | hardware | software | software |
| `rv32emf` | `ilp32e` | 16 | hardware | hardware | hardware | software |

The RV64 variants have the same 24 combinations with `rv64` in place of `rv32` and, in place of the ABIs `ilp32`, `ilp32f`, `ilp32d` and `ilp32e`, the ABIs `lp64`, `lp64f`, `lp64d` and `lp64e`. They are in the `base-picolibc-rv64` image, and the RV32 ones in `base-picolibc`.

The columns follow from the name of `-march`.

| Part of the name | Meaning |
| :--- | :--- |
| `rv32i` | 32 integer registers (`x0` to `x31`) |
| `rv32e` | 16 integer registers (`x0` to `x15`) |
| `_zmmul` | multiply in hardware, divide in software |
| `m` after the base | multiply and divide in hardware |
| `f` | single precision in hardware (it also brings `zicsr`, which the compiler adds to the name) |
| `fd` | single and double precision in hardware |

### 2.2. The extensions A, C and B

Each row of section 2.1 is built in eight versions, one for each choice of A, C and B. A variant with an extension holds code that uses it, so it runs only on a core that has that extension.

| Extension | What the library code uses | Effect |
| :--- | :--- | :--- |
| A | atomic instructions (`lr`, `sc` and the `amo` family) | a request with A takes only a variant with A, and one without A takes only a variant without it |
| C | 16-bit compressed instructions | smaller code |
| B | the instructions of Zba, Zbb and Zbs, such as shift-and-add, rotate, count of bits and single-bit operations | smaller and faster code in the routines that use them |

The three extensions of B are one choice, so a variant has all of them or none, and a request with only Zba and Zbb takes the variant without B.

### 2.3. ABIs

The ABI decides where `float` and `double` are passed, so a library only links with code built for the same ABI.

| `-mabi` | Base | `float` | `double` | Requires |
| :--- | :--- | :--- | :--- | :--- |
| `ilp32` | I | integer registers | pairs of integer registers | nothing |
| `ilp32f` | I | floating point registers | pairs of integer registers | F |
| `ilp32d` | I | floating point registers | floating point registers | F and D |
| `ilp32e` | E | integer registers | pairs of integer registers | nothing |
| `lp64` | I | integer registers | integer registers | nothing |
| `lp64f` | I | floating-point registers | integer registers | F |
| `lp64d` | I | floating-point registers | floating-point registers | F and D |
| `lp64e` | E | integer registers | integer registers | nothing |

`ilp32`, `ilp32e`, `lp64` and `lp64e` are soft-float ABIs. With F or D present the arithmetic inside a function still uses the hardware, and only the calls between functions pass the values in integer registers. RV32E has only `ilp32e`, so there is no E variant of `ilp32f` or `ilp32d`, and the compiler rejects D with `ilp32e`, so the E variants go up to F. The Q extension has no ABI in RV32 or RV64 and no variant. The rules of RV32E apply to RV64E, which has only `lp64e`.

### 2.4. Names in the installed tree

The compiler writes the name of each variant in a normalized form, and that name is the directory of the variant under `lib` in the sysroot and the one `-print-multi-lib` lists. It keeps the letters of the name and adds the extensions they imply.

| Letter in the name | What the compiler adds |
| :--- | :--- |
| `f` | `_zicsr` |
| `m` | `_zmmul` |
| `a` | `_zaamo_zalrsc` |
| `c` | `_zca`, plus `_zcf` with F and `_zcd` with D |
| the group B | nothing, the name already has `_zba_zbb_zbs` |

The extension added for `m` is not the variant `_zmmul` of section 2.1. The M extension includes Zmmul (the multiply) and adds the divide, so the compiler lists `_zmmul` in the name of every variant that has `m`, and a variant with only the multiply has `_zmmul` and no `m`. The added extensions come after the letters in the order `_zicsr`, `_zmmul`, `_zaamo_zalrsc`, `_zca`, `_zcd`, `_zcf` and `_zba_zbb_zbs`. The variant `rv32i/ilp32` is the default of the compiler, so it is installed at the root of `lib` and has no directory of its own.

| Variant of section 2.1 | Directory |
| :--- | :--- |
| `rv32if/ilp32` | `rv32if_zicsr/ilp32` |
| `rv32imc/ilp32` | `rv32imc_zmmul_zca/ilp32` |
| `rv32ec/ilp32e` | `rv32ec_zca/ilp32e` |
| `rv32ea/ilp32e` | `rv32ea_zaamo_zalrsc/ilp32e` |
| `rv32ifdc/ilp32d` | `rv32ifdc_zicsr_zca_zcd_zcf/ilp32d` |
| `rv32imc_zba_zbb_zbs/ilp32` | `rv32imc_zmmul_zca_zba_zbb_zbs/ilp32` |
| `rv32imafdc/ilp32d` | `rv32imafdc_zicsr_zmmul_zaamo_zalrsc_zca_zcd_zcf/ilp32d` |
| `rv64im/lp64` | `rv64im_zmmul/lp64` |
| `rv64imafdc/lp64d` | `rv64imafdc_zicsr_zmmul_zaamo_zalrsc_zca_zcd/lp64d` |

## 3. How the GCC chooses the variant

The compiler receives `-march` and `-mabi`, or uses the default of the build (`rv32i` with `ilp32`) when they are absent. It then takes the variant by these rules, and `--specs=picolibc.specs` finds `libc.a` in the directory of that same variant.

1. The ABI must be the one of the variant. There is no conversion between ABIs.
2. The `-march` of the variant must be a subset of the `-march` asked for. A library built for fewer extensions runs on a core with more of them, and not the other way around.
3. The variant and the request must agree on A, because the code of the support libraries changes with and without atomics.
4. Among the variants that satisfy the rules above, the one with the most extensions in common with the request is taken.

The extensions that have no variant of their own, such as Zicsr, Zifencei, Zicntr, Zihpm and Zicclsm, do not stop a request from taking a variant, and the request takes the one without them. The table uses the names of section 2.1, and section 2.4 gives the normalized names the compiler uses.

| Request | Variant used | Reason |
| :--- | :--- | :--- |
| `-march=rv32im -mabi=ilp32` | `rv32im/ilp32` | exact match |
| `-march=rv32imc -mabi=ilp32` | `rv32imc/ilp32` | C is a variant of its own |
| `-march=rv32ima -mabi=ilp32` | `rv32ima/ilp32` | A is a variant of its own |
| `-march=rv32imac_zicsr_zifencei -mabi=ilp32` | `rv32imac/ilp32` | Zicsr and Zifencei are ignored |
| `-march=rv32imc_zba_zbb -mabi=ilp32` | `rv32imc/ilp32` | B needs Zba, Zbb and Zbs together |
| `-march=rv32imc_zba_zbb_zbs -mabi=ilp32` | `rv32imc_zba_zbb_zbs/ilp32` | the three extensions of B |
| `-march=rv32imafdc -mabi=ilp32d` | `rv32imafdc/ilp32d` | exact match |
| `-march=rv32imfd -mabi=ilp32f` | `rv32imfd/ilp32f` | the library uses D in hardware and passes only `float` in registers |
| `-march=rv32ec -mabi=ilp32e` | `rv32ec/ilp32e` | the E base with C |
| `-march=rv32imf -mabi=ilp32e` | `rv32i/ilp32` | no variant has `ilp32e` with the I base, the compiler accepts it and takes the default directory |
| `-march=rv32im -mabi=ilp32f` | none, the compiler reports an error | `ilp32f` requires F |
| `-march=rv32efd -mabi=ilp32e` | none, the compiler reports an error | `ilp32e` does not support D |
| `-march=rv64imafdc -mabi=lp64d` | `rv64imafdc/lp64d` | exact match |
| `-march=rv64im -mabi=lp64` | `rv64im/lp64` | exact match |

The variant chosen for a build can be read with the commands below.

```bash
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -print-multi-directory
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 --specs=picolibc.specs -print-file-name=libc.a
riscv32-unknown-elf-gcc -print-multi-lib
```

## 4. C++ libraries

`libsupc++` and `libstdc++` are built in the same `Dockerfile`, after picolibc is installed and checked, against its headers and its `libc`. Each image builds the libraries of the variants of its width (192), in batches of `CXX_BATCH` variants (12 by default): each batch is configured, built and installed, and its build tree is deleted before the next one, which keeps the disk at about 0.65 GB for each variant of the batch.

| Item | Detail |
| :--- | :--- |
| Source | the `gcc` submodule of `riscv-gnu-toolchain` at the commit `GCC_COMMIT`, in a shallow clone. Its version must be that of the installed compiler |
| Libraries | `libsupc++.a`, `libstdc++.a` and `libstdc++exp.a`, one for each variant, in the directory of the variant under `lib` |
| Headers | `riscv32-unknown-elf/include/c++/<GCC version>`, in the sysroot, which `g++` finds with no extra option. `bits/c++config.h` is per variant, in `riscv32-unknown-elf/<directory of the variant>/bits`, and the one of the default variant is in `riscv32-unknown-elf/bits` |
| Exceptions and RTTI | enabled |
| `libatomic` | not built: the GCC marks it as unsupported for `riscv32-unknown-elf` |

A variant without the library does not compile C++, because its `c++config.h` is missing. The image of each width carries only the libraries of the variants of that width.

`picolibc.specs` links only the `crt0` and leaves `*endfile` empty, so a C++ program with exceptions needs `crtbegin` and `crtend`, which register and end the unwind frames. `picolibcpp.specs` (`--specs=picolibcpp.specs`) already links them, and it is the spec to use for C++. With `picolibc.specs`, the equivalent spec is:

```text
*startfile:
crt0-hosted%O%s crtbegin%O%s

*endfile:
crtend%O%s
```

A program that uses `new` or exceptions pulls in `getentropy` and `read` (and, for safety, `open` and `close`), which the runtime of the program defines, for example returning -1 with `errno` set to `ENOSYS`.

## 5. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/picolibc/Dockerfile` |
| Workflow | `Picolibc image` |
| Images | `base-picolibc` (`WIDTH=32`, the RV32 variants) and `base-picolibc-rv64` (`WIDTH=64`, the RV64 ones), built by the same workflow, one for each width |
| Tags | `<picolibc commit>-<GCC commit>` and `latest`, in each image |
| Labels | `picolibc.commit`, `riscv-gnu-toolchain.commit` and `riscv-gnu-toolchain.variants` (the number of variants of that GCC) |
| Schedule | every day, 03:10 UTC, and when `GCC image` finishes |

The workflow follows series 1 (`SERIES`), so the scheduled run takes the latest `1.x.y` release tag. The scheduled run waits for a `GCC image` run that is going, and the end of that run triggers this workflow again with the new GCC. The tag has the two commits only, so the run also compares the number of variants in the label of the image of that tag with the one of the GCC, and builds again when they differ. The two images are built together, and the lack of either one builds both.

## 6. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the picolibc commit; empty, the latest release tag of the series |
| `force` | rebuild and republish even if the image for that combination exists |

## 7. Building locally

```bash
docker build -f docker/base/picolibc/Dockerfile -t base-picolibc \
  --build-arg GCC_IMAGE=base-gcc \
  --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
  --build-arg GCC_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .
```

The 64-bit image comes from the same recipe:

```bash
docker build -f docker/base/picolibc/Dockerfile -t base-picolibc-rv64 --build-arg WIDTH=64 \
  --build-arg GCC_IMAGE=base-gcc --build-arg PICOLIBC_COMMIT=<commit> --build-arg GCC_COMMIT=<commit> .
```

The build takes hours, because it builds libstdc++ for 192 variants. The `MULTILIB` argument of [`base-gcc`](base-gcc.md) reduces the variants (picolibc follows the compiler's list), which shortens both builds.

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `GCC_IMAGE` | `base-gcc:latest` | the GCC that compiles picolibc |
| `PICOLIBC_COMMIT` | none | the picolibc commit to compile |
| `GCC_COMMIT` | none | the GCC commit of that image, where the libstdc++ source comes from, recorded in the tag |
| `WIDTH` | `32` | `32` builds the RV32 variants (the root and the `rv32` ones), and `64` the RV64 ones |
| `CXX_BATCH` | `12` | how many libstdc++ variants are built before the build tree is deleted |

## 8. Known limitations

What the image does not deliver, measured with GCC 16.1.0, and the consequence of each item.

| # | Limitation | Consequence |
| ---: | :--- | :--- |
| 1 | `libatomic` is out of scope. GCC marks it as unsupported for `riscv32-unknown-elf` (`libatomic/configure.tgt` treats `*-*-elf*` as `UNSUPPORTED`) | A 4-byte `std::atomic` is inlined in the variants with A. The 8-byte ones, and every atomic in the variants without A, become calls to `__atomic_*` that nothing defines, and the link fails |
| 2 | GCC does not support the Q extension (`extension 'q' is unsupported`, and the ABIs `ilp32q` and `lp64q` are refused) | C and C++ programs with Q do not compile. The assembler (`as`) accepts `-march=...q` and assembles instructions such as `fadd.q` |
| 3 | A `-march` and a `-mabi` with no exact variant fall to the root `.`, which is the `rv32i/ilp32` variant, with no error (for example `-march=rv32imf -mabi=ilp32e`, or a `-march=rv64*` of a variant the image does not have) | The program links against libraries of another width or base, with no warning. Tools refuses `core.type: 64` and checks the multilib it picks |
| 4 | `picolibc.specs` links neither `crtbegin.o` nor `crtend.o`, and `picolibc.ld` does not work for C++ (the link fails with `discarded section .eh_frame`) | For C++ use `--specs=picolibcpp.specs` and the linker script `picolibcpp.ld`, which link both and handle `.eh_frame` |
| 5 | `libstdc++` asks the runtime for `getentropy`, `read`, `open` and `close` | A program with `new` or exceptions fails to link without them. Tools generates stubs that return `ENOSYS` when `toolchain.cxx` is on |

---



Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
