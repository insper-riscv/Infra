# ci-elf

`ghcr.io/<organization>/ci-elf` is level 2 of the CI images, with what builds and runs an ELF, that is, what compiles assembly and C. It is [`ci-vhdl`](ci-vhdl.md) plus the RISC-V GCC with picolibc and libstdc++ ([`base-gcc`](base-gcc.md)) and Spike ([`base-spike`](base-spike.md)). [`ci-act4`](ci-act4.md) and the images after it are built on it. The overview of the images is in [README.md](README.md).

## 1. What it adds to ci-vhdl

| Component | Detail | Path |
| :--- | :--- | :--- |
| RISC-V GCC | `riscv32-unknown-elf` target, with the 384 library variants (192 of RV32 and 192 of RV64) of [`base-gcc`](base-gcc.md) | `/opt/riscv-foundation/riscv32-elf` |
| picolibc and libstdc++ | the C and C++ libraries of that GCC, from `base-picolibc` (the 32-bit variants) and `base-picolibc-rv64` (the 64-bit variants), compiled with it. The library directories of the two images do not overlap, and the files both have (headers, specs and linker scripts) are identical | `/opt/riscv-foundation/riscv32-elf` |
| Spike | with its debug module at `0x70000000` | `/opt/riscv-foundation/spike` |
| `libmpc3` and `libmpfr6` | the libraries `cc1` of the RISC-V GCC links against, from Ubuntu | `/usr/lib` |

The GCC, picolibc and Spike are already on the `PATH`. The executables of the RISC-V GCC are named `riscv32-unknown-elf-*`, so they do not clash with the host `gcc` that comes from `ci-vhdl`.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/ci/elf/Dockerfile` |
| Workflow | `CI images`, jobs `plan-elf` and `elf` |
| Tags | `latest`, `sha-<Infra commit>` and `vhdl-<12 of the digest>-gcc-<name>-picolibc-<name>-spike-<name>` |
| Labels | `riscv-gnu-toolchain.commit`, `picolibc.commit` and `riscv-isa-sim.commit` |
| Schedule | in the same run as `ci-vhdl`, right after it: every day, 03:00 UTC, and when `GCC image`, `Picolibc image` or `Spike image` finishes |

The picolibc is the latest `base-picolibc` and `base-picolibc-rv64`. The workflow assembles only when those two images were compiled with the latest `base-gcc`; if a `GCC image` or a `Picolibc image` run is going, it waits.

Before publishing, the workflow checks that the commits left in the image (the `.tag` files) are the pinned ones, that the GCC compiles with picolibc, that it has a libgcc, a libc and a libstdc++ for every library variant it lists, and that Spike does not place its debug module at address `0`.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `from_level` | the level to rebuild from (`vhdl`, `elf`, `act4` or `devtools`): it and the ones above it are rebuilt, the ones below are reused |

## 4. Building locally

```bash
docker build -f docker/ci/elf/Dockerfile -t ci-elf \
  --build-arg VHDL_IMAGE=ci-vhdl --build-arg GCC_IMAGE=base-gcc --build-arg PICOLIBC_IMAGE=base-picolibc \
  --build-arg PICOLIBC_RV64_IMAGE=base-picolibc-rv64 --build-arg SPIKE_IMAGE=base-spike .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `VHDL_IMAGE` | `ci-vhdl:latest` | the level below |
| `GCC_IMAGE` | `base-gcc:latest` | where the GCC comes from |
| `PICOLIBC_IMAGE` | `base-picolibc:latest` | where picolibc comes from |
| `PICOLIBC_RV64_IMAGE` | `base-picolibc-rv64:latest` | where the 64-bit variants of picolibc come from |
| `SPIKE_IMAGE` | `base-spike:latest` | where Spike comes from |

## 5. Verifying

```bash
docker run --rm ci-elf riscv32-unknown-elf-gcc --version
docker run --rm ci-elf riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm ci-elf spike --help
```

The second command prints one line for each library variant of [`base-gcc`](base-gcc.md).

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
