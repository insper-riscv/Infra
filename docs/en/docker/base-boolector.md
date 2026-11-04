# base-boolector

`ghcr.io/<organization>/base-boolector` holds Boolector, in `/opt/boolector`: the SMT solver for bit-vectors and arrays that `sby` runs as `smtbmc boolector`, with `btormc`, the model checker of the `btor` engine. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| Boolector | built from source, with the CaDiCaL SAT solver; only the executables, without headers or libraries |
| `boolector` and `btormc` | the solver and the model checker, both static |
| `btorsim` | the BTOR2 simulator that `sby` calls to replay a counterexample of the `btor` engine |
| `/opt/boolector/.tag` | two lines. The first is the commit the install was built from, and the second is the version of the release whose tag points at it and the short commit (`3.2.4 (...)`) |

Boolector is built here because the Ubuntu package is Boolector 1.5, which does not run in the incremental SMT-LIB mode (`--smt2 -i`) that `yosys-smtbmc` uses. `btorsim` links dynamically against the system's `libstdc++` and `libgcc_s`, so whoever copies the directory installs them.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/boolector/Dockerfile` |
| Workflow | `Boolector image` |
| Tags | `<commit>` and `latest` |
| Label | `boolector.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows series 3 (`SERIES`) and takes the latest `3.N.P` tag. The build only finishes if `boolector` solves a small query over bit-vectors in the incremental mode.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the Boolector commit; empty, the one of the latest tag of the series |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/boolector/Dockerfile -t base-boolector \
  --build-arg BOOLECTOR_COMMIT="$(git ls-remote https://github.com/Boolector/boolector 'refs/tags/3.2.4^{}' 'refs/tags/3.2.4' | tail -n 1 | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `BOOLECTOR_COMMIT` | none | the Boolector commit to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
