# base-picolibc

`ghcr.io/<organization>/base-picolibc` holds the files picolibc installs into the GCC's sysroot, under `/opt/riscv-foundation/riscv32-elf`. It is compiled with [`base-gcc`](base-gcc.md), and [`ci-elf`](ci-elf.md) copies it over the GCC's prefix. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| picolibc | the C library compiled by the GCC of the latest `base-gcc`, installed into the sysroot, once for each variant of that GCC (`rv32i/ilp32`, `rv32i_zmmul/ilp32`, `rv32im/ilp32`, `rv32imf/ilp32f` and `rv32imfd/ilp32d`) |

picolibc is compiled by a cross compiler, so the build uses the latest GCC image. The image carries the commit of that GCC in the label `riscv-gnu-toolchain.commit`, and a new GCC makes a new picolibc build.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/picolibc/Dockerfile` |
| Workflow | `Picolibc image` |
| Tags | `<picolibc commit>-<GCC commit>` and `latest` |
| Labels | `picolibc.commit` and `riscv-gnu-toolchain.commit` |
| Schedule | every day, 03:10 UTC, and when `GCC image` finishes |

The workflow follows series 1 (`SERIES`), so the scheduled run takes the latest `1.x.y` release tag. The scheduled run waits for a `GCC image` run that is going, and the end of that run triggers this workflow again with the new GCC.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the picolibc commit; empty, the latest release tag of the series |
| `force` | rebuild and republish even if the image for that combination exists |

## 4. Building locally

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
