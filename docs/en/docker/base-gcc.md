# base-gcc

`ghcr.io/<organization>/base-gcc` holds the RISC-V GCC, with no C library, in `/opt/riscv-foundation/riscv32-elf`. [`base-picolibc`](base-picolibc.md) is compiled with it, and [`ci-elf`](ci-elf.md) copies both. The overview of the images is in [README.md](README.md), and the step by step of building the GCC by hand is in [GCC_SETUP.md](../manual/GCC_SETUP.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| binutils | the assembler, linker and archiver for the `riscv32-unknown-elf` target |
| RISC-V GCC | `riscv32-unknown-elf` target, C and C++ front ends, with the library variants of section 1.1 |
| libgcc | the compiler's support library, built with that compiler |
| `/opt/riscv-foundation/riscv32-elf/.tag` | the `riscv-gnu-toolchain` commit the install was built from |

### 1.1. Variants

| Base and floating point | `-march` (each with no multiply, `_zmmul` and `m`) | `-mabi` |
| :--- | :--- | :--- |
| I, no floating point | `rv32i`, `rv32i_zmmul`, `rv32im` | `ilp32` |
| I with F | `rv32if`, `rv32if_zmmul`, `rv32imf` | `ilp32`, `ilp32f` |
| I with F and D | `rv32ifd`, `rv32ifd_zmmul`, `rv32imfd` | `ilp32`, `ilp32f`, `ilp32d` |
| E, no floating point | `rv32e`, `rv32e_zmmul`, `rv32em` | `ilp32e` |
| E with F | `rv32ef`, `rv32ef_zmmul`, `rv32emf` | `ilp32e` |

That makes 24 variants, with `rv32im/ilp32` the default. `_zmmul` is multiply in hardware and divide in software, `m` is both in hardware, and the name with neither has both in software. RV32E allows only the `ilp32e` ABI (soft-float, so `float` is passed in integer registers even when F is present), and that ABI does not support D, so there is no E variant with D. The hard-float ABIs `ilp32f` and `ilp32d` exist only for I. The Q extension has no RV32 ABI, so it has no variant.

A library built for a smaller set of extensions runs on a core with more of them, and not the other way around, so a core uses the variant that matches what it has and any other variant a subset of it. The compiler selects the variant by the `-march` and `-mabi` given and takes the largest variant that is a subset of what was asked: `rv32ic` takes `rv32i`, and `rv32imc` and `rv32ima` take `rv32im`. The E variants (16 registers) use the `ilp32e` ABI, the only one RV32E allows, and do not link with the I ones; `rv32ec` takes `rv32e`. The floating point variants do not link with the integer ones, because the ABI changes how `float` and `double` are passed. `libgcc` is built for each variant. The compiler reports a variant that has F with `zicsr` and `zmmul` in its name, because F needs Zicsr; the names are normalized by the compiler, and `-print-multi-lib` lists them.

The build installs binutils and the first compiler of the picolibc configuration, then builds libgcc with it; the second stage of `riscv-gnu-toolchain`, which would rebuild the compiler and libgcc against picolibc, is not run. `cc1` links against `libmpc3` and `libmpfr6`, installed in `ci-elf`. The image has no C library and no libstdc++. picolibc comes from `base-picolibc`, and C++ programs that need the standard library are out of scope. The executables are named `riscv32-unknown-elf-*`, so they do not clash with the host `gcc`.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/gcc/Dockerfile` |
| Workflow | `GCC image` |
| Tags | `<GCC commit>` and `latest` |
| Label | `riscv-gnu-toolchain.commit` |
| Schedule | every day, 03:00 UTC |

The GCC has no release to follow, so the scheduled run takes the latest commit of the `master` branch of `riscv-gnu-toolchain` on which its `Build` workflow succeeded, and builds only if the image for that commit does not exist. The upstream `Build` takes hours, so that commit is usually about a day behind the head, and a commit still running is skipped, not waited for. A commit whose `Build` failed or was cancelled is skipped too. The image depends on no other image.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the `riscv-gnu-toolchain` commit; empty, the latest one whose upstream `Build` succeeded |
| `ignore_ci` | with no `commit`, take the head of the `master` branch whatever its CI says |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/gcc/Dockerfile -t base-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .
```

The build takes from tens of minutes to over an hour, depending on the machine.

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `RISCV_GNU_TOOLCHAIN_COMMIT` | none | the `riscv-gnu-toolchain` commit |
| `MULTILIB` | the variants above | the variants, in the format of the GCC option `--with-multilib-generator` |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
