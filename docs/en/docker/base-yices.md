# base-yices

`ghcr.io/<organization>/base-yices` holds Yices 2, in `/opt/yices`: the SMT solver that `sby` runs as `smtbmc yices`. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| Yices 2 | built from source; only the executables (`yices-smt2`, `yices`, `yices-sat` and `yices-smt`), without headers or libraries |
| `/opt/yices/.tag` | two lines. The first is the commit the install was built from, and the second is the version of the release whose tag points at it and the short commit (`2.6.5 (...)`) |

`yices-smt2` links dynamically against the system's `libgmp` and `libc`, so whoever copies the directory installs `libgmp10`.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/yices/Dockerfile` |
| Workflow | `Yices image` |
| Tags | `<commit>` and `latest` |
| Label | `yices.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows series 2 (`SERIES`) and takes the latest `Yices-2.N.P` tag. The build only finishes if the executable solves a small query over bit-vectors.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the Yices commit; empty, the one of the latest tag of the series |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/yices/Dockerfile -t base-yices \
  --build-arg YICES_COMMIT="$(git ls-remote https://github.com/SRI-CSL/yices2 'refs/tags/Yices-2.6.5^{}' 'refs/tags/Yices-2.6.5' | tail -n 1 | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `YICES_COMMIT` | none | the Yices commit to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
