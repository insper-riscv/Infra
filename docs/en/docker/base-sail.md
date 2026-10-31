# base-sail

`ghcr.io/<organization>/base-sail` holds the Sail RISC-V model (`sail_riscv_sim`) compiled from one commit of `riscv/sail-riscv`, in `/opt/riscv-foundation/sail`. [`ci-act4`](ci-act4.md) copies that directory. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| `sail_riscv_sim` | the model's executable, statically linked, in `/opt/riscv-foundation/sail/bin` |

The build fetches the commit by its hash, downloads the Sail compiler that commit requires (`cmake/sail_required_version.txt`, the binary release of `rems-project/sail` for the build's architecture) and compiles the model with CMake and Ninja, the way the upstream compiles its release. It then checks that `sail_riscv_sim --version` prints the release number the commit declares in `cmake/project_version.cmake`, which is the value ACT4 compares with its own requirement, and that the executable has no missing library. Any mismatch fails the build.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/sail/Dockerfile` |
| Workflow | `Sail image` |
| Tags | the commit, and `latest` |
| Labels | `sail-riscv.version` (the release number the commit declares) and `sail-riscv.commit` |
| Schedule | every day, 03:00 UTC |

The commit is the latest one on the `master` branch of `riscv/sail-riscv` on which the upstream's own `ci.yml` workflow finished successfully. The upstream merges through a merge queue, so that workflow runs on `merge_group` as well as on `push`, and a success on either counts. A commit still running is waited for a few minutes and one that failed is skipped.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the commit to build (full hash); empty, the latest one on `master` with a green `ci.yml` |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/sail/Dockerfile -t base-sail \
  --build-arg SAIL_COMMIT=<full commit hash> \
  --build-arg SAIL_VERSION=0.16 .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `SAIL_COMMIT` | none | the `riscv/sail-riscv` commit |
| `SAIL_VERSION` | none | the release number the commit declares |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
