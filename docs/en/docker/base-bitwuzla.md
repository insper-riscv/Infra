# base-bitwuzla

`ghcr.io/<organization>/base-bitwuzla` holds Bitwuzla, in `/opt/bitwuzla`: the SMT solver for bit-vectors and arrays that `sby` runs as `smtbmc bitwuzla`. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| Bitwuzla | built from source; only the `bitwuzla` executable, without headers or libraries |
| `/opt/bitwuzla/.tag` | two lines. The first is the commit the install was built from, and the second is the version of the release whose tag points at it and the short commit (`0.9.1 (...)`) |

The executable is static, so whoever copies the directory installs no library.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/bitwuzla/Dockerfile` |
| Workflow | `Bitwuzla image` |
| Tags | `<commit>` and `latest` |
| Label | `bitwuzla.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows series 0 (`SERIES`) and takes the latest `0.N.P` tag. The build only finishes if the executable solves a small query over bit-vectors.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the Bitwuzla commit; empty, the one of the latest tag of the series |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/bitwuzla/Dockerfile -t base-bitwuzla \
  --build-arg BITWUZLA_COMMIT="$(git ls-remote https://github.com/bitwuzla/bitwuzla 'refs/tags/0.9.1^{}' 'refs/tags/0.9.1' | tail -n 1 | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `BITWUZLA_COMMIT` | none | the Bitwuzla commit to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
