# base-sail

`ghcr.io/<organization>/base-sail` holds the Sail RISC-V model (`sail_riscv_sim`) of a release, in `/opt/riscv-foundation/sail`. [`ci-elf`](ci-elf.md) copies that directory. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| `sail_riscv_sim` | the model's executable, with the libraries the release tarball brings, in `/opt/riscv-foundation/sail/bin` |

The build downloads the tarball of the `riscv/sail-riscv` release for the build's architecture (`x86_64` or `aarch64`), checks its SHA-256 against the one GitHub publishes for the asset, extracts it into `/opt/riscv-foundation/sail` and runs `sail_riscv_sim --version`. Any mismatch fails the build.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `Dockerfile.sail-img` |
| Workflow | `Sail image` |
| Tags | the commit of the release tag, and `latest` |
| Labels | `sail-riscv.version` and `sail-riscv.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows series 0 (`SERIES`), whose releases are named `0.N`. The weekly pre-releases of the upstream are not stable releases and never enter.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `version` | the release to build; empty, the latest stable one of the series |
| `force` | rebuild and republish even if the image for that release exists |

## 4. Building locally

```bash
docker build -f Dockerfile.sail-img -t base-sail \
  --build-arg SAIL_VERSION=0.16 \
  --build-arg SAIL_SHA256_AMD64=<digest of sail-riscv-Linux-x86_64.tar.gz> \
  --build-arg SAIL_SHA256_ARM64=<digest of sail-riscv-Linux-aarch64.tar.gz> .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `SAIL_VERSION` | none | the `riscv/sail-riscv` release |
| `SAIL_SHA256_AMD64` | none | the SHA-256 of the `x86_64` tarball |
| `SAIL_SHA256_ARM64` | none | the SHA-256 of the `aarch64` tarball |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
