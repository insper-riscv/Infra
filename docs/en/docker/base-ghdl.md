# base-ghdl

`ghcr.io/<organization>/base-ghdl` holds only GHDL, in `/opt/ghdl`. [`ci-vhdl`](ci-vhdl.md) copies that directory. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| GHDL | LLVM backend, built from source, in `/opt/ghdl` |
| `/opt/ghdl/.tag` | the commit of `ghdl/ghdl` the install was built from |

The LLVM backend runs on `amd64` and `arm64`, unlike `mcode`, which is x86 only; the two architectures must run the same simulator. With this backend `ghdl -r` needs a prior `ghdl -e` (or `ghdl --elab-run`). GHDL links against `libgnat`, `libllvm`, `zlib1g` and `libedit2`, installed in `ci-vhdl`.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `Dockerfile.ghdl` |
| Workflow | `GHDL image` |
| Tags | `<commit>` and `latest` |
| Label | `ghdl.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows series 6 of GHDL (`SERIES`), so a new series is chosen by editing that line. The scheduled run takes the commit of the latest `6.x.y` release tag and builds only if the image for that commit does not exist.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the commit to build; empty, the one of the latest release tag |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f Dockerfile.ghdl -t base-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl 'refs/tags/v6.0.0^{}' | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `GHDL_COMMIT` | none | the commit of `ghdl/ghdl` to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
