# base-picolibc

`ghcr.io/<organization>/base-picolibc` holds the files picolibc installs into the GCC's sysroot, under `/opt/riscv-foundation/riscv32-elf`. It is compiled with [`base-gcc`](base-gcc.md), and [`ci-elf`](ci-elf.md) copies it over the GCC's prefix. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| picolibc | the C library compiled by the GCC of the latest `base-gcc`, installed into the sysroot, once for each of the 192 variants of that GCC (section 2.1) |

The file `/opt/riscv-foundation/riscv32-elf/.picolibc.tag` has two lines. The first is the picolibc commit, and the second is the version, the short commit and the number of library variants (`1.8.12 (2ae376c), 192 variants`).

picolibc is compiled by a cross compiler, so the build uses the latest GCC image. The image carries the commit of that GCC in the label `riscv-gnu-toolchain.commit`, and a new GCC makes a new picolibc build.

## 2. Variants

### 2.1. What runs in hardware and what in software

Every row is a combination of base, multiply and floating point, built in eight versions (section 2.2), and each version is one library installed into the sysroot. An operation marked software is a call to a routine of `libgcc` (for example `__mulsi3`, `__divsi3`, `__addsf3` and `__adddf3`), so a core without the extension still runs the program, only slower.

| `-march` | `-mabi` | Integer registers | Multiply | Divide | Single precision (`float`) | Double precision (`double`) |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `rv32i` | `ilp32` | 32 | software | software | software | software |
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
| `rv32im` (default) | `ilp32` | 32 | hardware | hardware | software | software |
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

`ilp32` and `ilp32e` are soft-float ABIs. With F or D present the arithmetic inside a function still uses the hardware, and only the calls between functions pass the values in integer registers. RV32E has only `ilp32e`, so there is no E variant of `ilp32f` or `ilp32d`, and the compiler rejects D with `ilp32e`, so the E variants go up to F. The Q extension has no ABI in RV32 and no variant.

### 2.4. Names in the installed tree

The compiler writes the name of each variant in a normalized form, and that name is the directory of the variant under `lib` in the sysroot and the one `-print-multi-lib` lists. It keeps the letters of the name and adds the extensions they imply.

| Letter in the name | What the compiler adds |
| :--- | :--- |
| `f` | `_zicsr` |
| `m` | `_zmmul` |
| `a` | `_zaamo_zalrsc` |
| `c` | `_zca`, plus `_zcf` with F and `_zcd` with D |
| the group B | nothing, the name already has `_zba_zbb_zbs` |

The extension added for `m` is not the variant `_zmmul` of section 2.1. The M extension includes Zmmul (the multiply) and adds the divide, so the compiler lists `_zmmul` in the name of every variant that has `m`, and a variant with only the multiply has `_zmmul` and no `m`. The added extensions come after the letters in the order `_zicsr`, `_zmmul`, `_zaamo_zalrsc`, `_zca`, `_zcd`, `_zcf` and `_zba_zbb_zbs`. The variant `rv32im/ilp32` is the default of the compiler, so it is installed at the root of `lib` and has no directory of its own.

| Variant of section 2.1 | Directory |
| :--- | :--- |
| `rv32if/ilp32` | `rv32if_zicsr/ilp32` |
| `rv32imc/ilp32` | `rv32imc_zmmul_zca/ilp32` |
| `rv32ec/ilp32e` | `rv32ec_zca/ilp32e` |
| `rv32ea/ilp32e` | `rv32ea_zaamo_zalrsc/ilp32e` |
| `rv32ifdc/ilp32d` | `rv32ifdc_zicsr_zca_zcd_zcf/ilp32d` |
| `rv32imc_zba_zbb_zbs/ilp32` | `rv32imc_zmmul_zca_zba_zbb_zbs/ilp32` |
| `rv32imafdc/ilp32d` | `rv32imafdc_zicsr_zmmul_zaamo_zalrsc_zca_zcd_zcf/ilp32d` |

## 3. How the GCC chooses the variant

The compiler receives `-march` and `-mabi`, or uses the default of the build (`rv32im` with `ilp32`) when they are absent. It then takes the variant by these rules, and `--specs=picolibc.specs` finds `libc.a` in the directory of that same variant.

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
| `-march=rv32imf -mabi=ilp32e` | `rv32im/ilp32` | no variant has `ilp32e` with the I base, the compiler accepts it and takes the default directory |
| `-march=rv32im -mabi=ilp32f` | none, the compiler reports an error | `ilp32f` requires F |
| `-march=rv32efd -mabi=ilp32e` | none, the compiler reports an error | `ilp32e` does not support D |

The variant chosen for a build can be read with the commands below.

```bash
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -print-multi-directory
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 --specs=picolibc.specs -print-file-name=libc.a
riscv32-unknown-elf-gcc -print-multi-lib
```

## 4. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/picolibc/Dockerfile` |
| Workflow | `Picolibc image` |
| Tags | `<picolibc commit>-<GCC commit>` and `latest` |
| Labels | `picolibc.commit`, `riscv-gnu-toolchain.commit` and `riscv-gnu-toolchain.variants` (the number of variants of that GCC) |
| Schedule | every day, 03:10 UTC, and when `GCC image` finishes |

The workflow follows series 1 (`SERIES`), so the scheduled run takes the latest `1.x.y` release tag. The scheduled run waits for a `GCC image` run that is going, and the end of that run triggers this workflow again with the new GCC. The tag has the two commits only, so the run also compares the number of variants in the label of the image of that tag with the one of the GCC, and builds again when they differ.

## 5. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the picolibc commit; empty, the latest release tag of the series |
| `force` | rebuild and republish even if the image for that combination exists |

## 6. Building locally

```bash
docker build -f docker/base/picolibc/Dockerfile -t base-picolibc \
  --build-arg GCC_IMAGE=base-gcc \
  --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
  --build-arg GCC_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `GCC_IMAGE` | `base-gcc:latest` | the GCC that compiles picolibc |
| `PICOLIBC_COMMIT` | none | the picolibc commit to compile |
| `GCC_COMMIT` | none | the GCC commit of that image, recorded in the tag |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
