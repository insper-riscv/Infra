# ci-vhdl

`ghcr.io/<organization>/ci-vhdl` is level 1 of the CI images, with what a VHDL test needs. It copies [`base-ghdl`](base-ghdl.md) and [`base-yosys`](base-yosys.md), and [`ci-asm`](ci-asm.md) and the images after it are built on it. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Component | Detail | Path |
| :--- | :--- | :--- |
| GHDL | LLVM backend, from `base-ghdl` | `/opt/ghdl` |
| Yosys | reads the Verilog netlist GHDL synthesizes from the VHDL, from `base-yosys` | `/opt/yosys` |
| SymbiYosys (`sby`) | runs Yosys and the solvers, from `base-yosys` | `/opt/yosys` |
| `z3` and `boolector` | the SMT solvers SymbiYosys uses, from Ubuntu | `/usr/bin` |
| `uv` | Python project manager, installed by the official installer of the chosen version, which checks the binary against the SHA-256 it carries | `/usr/local/bin` |
| Python | 3.14, installed by `uv` for every user, with `python3` and `python` on the `PATH` | `/opt/uv/python` |
| cocotb | 2.1.0, installed in that Python | `/opt/uv/python` |
| `click` | 8.5.0, the Python library `sby` imports, installed by `uv` | `/opt/uv/python` |

The host `gcc` and `g++` are in the image too. The LLVM backend links the design it elaborates with `gcc`, and cocotb is compiled with `g++` on `arm64`, where it has no wheel for Linux; a project's `uv sync` compiles it there as well. The image has no `pip`; a project installs its other dependencies with `uv sync`, which finds this Python instead of downloading another.

Python is pinned to 3.14 because the latest cocotb, 2.1.0, supports Python up to 3.14, which is why the projects require it (`>=3.14,<3.15`). A newer Python waits for a cocotb that supports it (the build arguments `PYTHON_VERSION` and `COCOTB_VERSION` change both together).

Ubuntu also provides `git`, `make`, `curl` and `ca-certificates` (the checkout of a workflow, the projects' Makefiles, the installers and the certificates with which `curl` and `git` verify HTTPS servers), the library `libglib2.0-0t64`, which the command-line tools of a Quartus installation mounted from the host use and the Ubuntu base image does not have, the libraries GHDL links against (`libgnat`, `libllvm`, `zlib1g-dev`, `libedit2`) and the ones Yosys links against (`libreadline8t64`, `libtcl8.6`, `libffi8`).

### 1.1. What updates by itself and what is fixed

| Item | Version | Changes when |
| :--- | :--- | :--- |
| GHDL, Yosys, SymbiYosys | those of `base-ghdl` and `base-yosys` | those images get a new version (automatic) |
| `uv` | the latest stable release of series 0 | `uv` releases a new version (automatic, checked every day) |
| Python | the latest patch of 3.14 that the `uv` of the image knows | a new `uv` is released (automatic); the minor changes only by editing `PYTHON_VERSION` |
| cocotb | 2.1.0, fixed | `COCOTB_VERSION` is edited |
| `click` | 8.5.0, fixed | `CLICK_VERSION` is edited |
| `z3`, `boolector` and the other Ubuntu packages | whatever Ubuntu 26.04 has when the image is built | the image is rebuilt for another reason |

The image is rebuilt only when GHDL, Yosys, SymbiYosys or `uv` change. The Python patch follows the `uv`, because a new `uv` brings the new patch with it, but cocotb and `click` do not follow it: they stay at the versions `docker/ci/vhdl/Dockerfile` fixes until someone edits the build argument and runs the workflow by hand with `force`. The Python, cocotb and `click` versions are in the long tag and in the labels of every image, and are not part of the decision to build.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/ci/vhdl/Dockerfile` |
| Workflow | `VHDL image` |
| Tags | `latest`, `sha-<Infra commit>`, `ghdl-<7>-yosys-<7>-sby-<7>-uv-<version>` and the same with `-python-<x.y.z>-cocotb-<version>-click-<version>` at the end |
| Labels | `ghdl.commit`, `yosys.commit`, `sby.commit`, `uv.version`, `python.version`, `cocotb.version` and `click.version` |
| Schedule | every day, 03:00 UTC, and when `GHDL image` or `Yosys image` finishes |

`uv` is the one component with no image of ours. Every run takes the latest stable release of the series set in `UV_SERIES` (`0`), or the `uv_version` field of a manual run. The version goes into the combination tag, so a run for a version that is already published assembles nothing, and a new `uv` is picked up by the first run after its release.

Before publishing, the workflow checks that the commit each component left in the image (its `.tag` file) is the one pinned for it.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `uv_version` | the `uv` version; empty, the latest stable one of the series |

## 4. Building locally

```bash
docker build -f docker/ci/vhdl/Dockerfile -t ci-vhdl \
  --build-arg GHDL_IMAGE=base-ghdl --build-arg YOSYS_IMAGE=base-yosys \
  --build-arg UV_VERSION="$(git ls-remote --tags --refs https://github.com/astral-sh/uv '0.*' | sed 's|.*refs/tags/||' | grep -E '^0\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `GHDL_IMAGE` | `base-ghdl:latest` | where GHDL comes from |
| `YOSYS_IMAGE` | `base-yosys:latest` | where Yosys and SymbiYosys come from |
| `UV_VERSION` | none (required) | `uv` version; the build fails with a message if it is missing |
| `PYTHON_VERSION` | `3.14` | Python installed by `uv` |
| `COCOTB_VERSION` | `2.1.0` | cocotb installed in it |
| `CLICK_VERSION` | a fixed version | `click`, used by `sby` |

The build prints one line per component with its version and commit, and fails if GHDL does not run a VHDL-2008 design, if Yosys and `sby` do not prove a small property with `z3`, or if Python is not 3.14 with cocotb.

## 5. Uses

### 5.1. Formal verification

GHDL turns a VHDL entity into a Verilog netlist, which Yosys reads and SymbiYosys proves properties on. The properties are written in SystemVerilog around the netlist, so no GHDL plugin for Yosys is needed:

```bash
ghdl -a --std=08 --workdir=work my_block.vhd
ghdl --synth --std=08 --workdir=work --out=verilog my_block > my_block.v
sby -f my_block.sby
```

The `.sby` file names the mode (`prove` for an unbounded proof by induction, `bmc` for a bounded check, `cover` to confirm the properties are not vacuous), the depth, the engine (`smtbmc z3`) and the files. A proof that fails writes a waveform of the counterexample next to the log.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
