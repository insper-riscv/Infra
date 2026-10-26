# base-yosys

`ghcr.io/<organization>/base-yosys` holds Yosys and SymbiYosys (`sby`), in `/opt/yosys`. [`ci-vhdl`](ci-vhdl.md) copies that directory. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| Yosys | built from source; reads the Verilog netlist GHDL synthesizes from the VHDL |
| SymbiYosys (`sby`) | built with Yosys; runs Yosys and the solvers |
| `/opt/yosys/.tag` and `/opt/yosys/.sby.tag` | the commits the install was built from |

The `z3` and `boolector` solvers come from Ubuntu and are installed in `ci-vhdl`, which also installs the libraries Yosys links against (`libreadline8t64`, `libtcl8.6` and `libffi8`) and the `click` that `sby` imports.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/yosys/Dockerfile` |
| Workflow | `Yosys image` |
| Tags | `<Yosys commit>-<sby commit>` and `latest` |
| Labels | `yosys.commit` and `sby.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows series 0 (`SERIES`) and takes the latest `v0.N` release of Yosys with the `sby` tag of the same version, because the two are released in step (`v0.N` of one with `v0.N` of the other).

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the Yosys commit; empty, the one of the latest release |
| `sby_commit` | the `sby` commit; empty, the `sby` tag with the same version as the Yosys release |
| `force` | rebuild and republish even if the image for that combination exists |

## 4. Building locally

```bash
docker build -f docker/base/yosys/Dockerfile -t base-yosys \
  --build-arg YOSYS_COMMIT="$(git ls-remote https://github.com/YosysHQ/yosys 'refs/tags/v0.70^{}' | cut -f1)" \
  --build-arg SBY_COMMIT="$(git ls-remote https://github.com/YosysHQ/sby 'refs/tags/v0.70^{}' | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `YOSYS_COMMIT` | none | the Yosys commit to build |
| `SBY_COMMIT` | none | the `sby` commit to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
