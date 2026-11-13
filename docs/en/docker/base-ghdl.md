# base-ghdl

`ghcr.io/<organization>/base-ghdl` holds only GHDL, in `/opt/ghdl`. [`ci-vhdl`](ci-vhdl.md) copies that directory. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| GHDL | LLVM backend, built from source, in `/opt/ghdl` |
| `/opt/ghdl/.tag` | two lines. The first is the commit of `ghdl/ghdl` the install was built from, and the second is the version of the release whose tag points at it and the short commit (`6.0.0 (42d3f16)`) |

The LLVM backend runs on `amd64` and `arm64`, unlike `mcode`, which is x86 only; the two architectures must run the same simulator. With this backend `ghdl -r` needs a prior `ghdl -e` (or `ghdl --elab-run`). GHDL links against `libgnat`, `libllvm`, `zlib1g` and `libedit2`, installed in `ci-vhdl`.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/ghdl/Dockerfile` |
| Workflow | `GHDL image` |
| Tags | `<commit>` and `latest` |
| Label | `ghdl.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows the head of the default branch of GHDL (the 7.0.0-dev line), because the GHDL plugin for Yosys needs an API of GHDL that the 6.0.0 release does not have. The scheduled run takes the latest commit of that branch and builds only if the image for that commit does not exist.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the commit to build; empty, the head of the default branch |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/ghdl/Dockerfile -t base-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl HEAD | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `GHDL_COMMIT` | none | the commit of `ghdl/ghdl` to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
