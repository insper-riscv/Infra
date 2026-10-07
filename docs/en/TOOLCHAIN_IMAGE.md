# Toolchain Docker images

Four Docker images with what the RISC-V test flow needs except Quartus: one with just GHDL, one with just the GCC, one with just Spike, and a complete one (GHDL, the RISC-V GCC with picolibc, Spike and `uv`) that copies the artifacts of the first three. The `Dockerfile`s are at the root of this repository, and four workflows publish the images to the GitHub Container Registry. Every image is published for `linux/amd64` and `linux/arm64`, and the two architectures hold the same versions of the same tools: GHDL has the LLVM backend on both, so a simulation behaves the same on a PC and on an ARM machine such as a Mac.

## 1. The four images

| Image | `Dockerfile` | Workflow | Contents | Tags |
| :--- | :--- | :--- | :--- | :--- |
| `ghcr.io/<organization>/infra-ghdl` | `Dockerfile.ghdl` | `GHDL image` | Just `/opt/ghdl` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-gcc` | `Dockerfile.gcc` | `GCC image` | Just `/opt/riscv-foundation/riscv32-elf` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-spike` | `Dockerfile.spike` | `Spike image` | Just `/opt/riscv-foundation/spike` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-toolchain` | `Dockerfile` | `Toolchain image` | The complete image | `latest`, `sha-<Infra commit>` and `ghdl-<first 7>-gcc-<first 7>-spike-<first 7>` |

The `<commit>` of the first three is the commit of `ghdl/ghdl` (the release tag's), `riscv-collab/riscv-gnu-toolchain` and `riscv-software-src/riscv-isa-sim` they were built from, and it is also in the image's `ghdl.commit`, `riscv-gnu-toolchain.commit` or `riscv-isa-sim.commit` label. The component images have no file system besides those directories, so they cannot be run: they exist to be copied from.

## 2. What the complete image contains

| Component | Detail | Path |
| :--- | :--- | :--- |
| GHDL | LLVM backend, built from source (the mcode backend of the `ghdl/ghdl` images is x86 only, and the two architectures must run the same GHDL) | `/opt/ghdl` |
| RISC-V GCC | `rv32im`/`ilp32` target with picolibc, a single library variant (what [GCC_SETUP.md](GCC_SETUP.md) builds) | `/opt/riscv-foundation/riscv32-elf` |
| Spike | With its debug module moved from address `0x0` to `0x70000000` (what [SPIKE_SETUP.md](SPIKE_SETUP.md) builds) | `/opt/riscv-foundation/spike` |
| `uv` | Python project manager | `/usr/local/bin` |
| Python | 3.14, installed by `uv` for every user, with `python3` and `python` on the `PATH` | `/opt/uv/python` |
| cocotb | 2.1.0, installed in that Python | `/opt/uv/python` |

GHDL, the GCC and Spike are already on the image's `PATH`. The host `gcc` is in the image too, because the LLVM backend links the design it elaborates with it; the RISC-V one keeps its own `riscv32-unknown-elf-` names. With the LLVM backend `ghdl -r` needs a prior `ghdl -e` (or use `ghdl --elab-run`); the Makefiles and the simulation runner already do. Each install keeps in `.tag` the commit it was built from, and the complete image carries the three commit labels.

Python is pinned to 3.14 because that is the version the projects require (`>=3.14,<3.15`), and cocotb 2.1.0 is the first release that supports it: cocotb is what fixes the Python version, so a newer Python waits for a cocotb that supports it (the build arguments `PYTHON_VERSION` and `COCOTB_VERSION` change both together). Every project simulates with cocotb, so it is in the image (cocotb 2.1.0 has wheels for Python 3.14 on Linux x86-64, macOS and Windows but not on Linux arm64, so on arm64 it is compiled, which is why the image has `g++`, and a project's `uv sync` compiles it there too); the other Python libraries are each project's own and come from its `uv sync`, which finds this Python instead of downloading one.

Quartus is in none of the images, and a container cannot see the USB-Blaster without extra host configuration. The real-hardware tests therefore split the work: the test ROMs and their goldens are built inside the complete image, and Quartus and the JTAG cable are used from the self-hosted runner described in [RUNNER_SETUP.md](RUNNER_SETUP.md), which needs Docker and access to it.

## 3. Using the complete image

Interactively, with the current directory mounted:

```bash
docker run --rm -it -v "$PWD:/workspace" ghcr.io/insper-riscv/infra-toolchain:latest
```

In a GitHub Actions job:

```yaml
jobs:
  sim:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/insper-riscv/infra-toolchain:latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: riscv32-unknown-elf-gcc --version
```

For a reproducible result, use the `sha-<commit>` tag of the wanted publication instead of `latest`.

## 4. Updating GHDL, the GCC or Spike

Each component has a manually run workflow. In Actions, pick `GHDL image`, `GCC image` or `Spike image` and click **Run workflow**, filling in:

| Field | Meaning |
| :--- | :--- |
| `confirm` | The value of the `IMAGE_PUBLISH_SECRET` secret (see section 6) |
| `commit` | The commit to build. Empty: the latest of the project's default branch (for GHDL, the commit of its latest release tag) |
| `force` | Rebuild and republish even if the image for that commit already exists |

The workflow resolves the commit, checks whether `infra-gcc:<commit>` (or `infra-spike:<commit>`) already exists and, if it does and `force` is off, builds nothing. Otherwise it builds, checks the install and publishes it with the tags `<commit>` and `latest`.

The component workflows also run by themselves on a push to `main` that changes their own `Dockerfile.ghdl`, `Dockerfile.gcc` or `Dockerfile.spike`, or the workflow itself. There is no `commit` field then: they rebuild the commit the `latest` image already has (the recipe changed, not the version) with `force` on, and only use the latest upstream commit when nothing is published yet. So the merge that adds the `Dockerfile`s already publishes the components for the first time.

When one of these workflows finishes successfully, `Toolchain image` runs by itself: it reads the commits from the labels of the three `latest` images and assembles and publishes a new complete image. Updating just Spike takes a few minutes, and updating the GCC or GHDL takes from tens of minutes to over an hour.

Each architecture is built on a runner of its own (`ubuntu-26.04` for `linux/amd64` and `ubuntu-24.04-arm` for `linux/arm64`): the GCC and GHDL builds take hours under emulation. A final job joins the two images into one manifest with the tags, so `docker pull` gives each machine its own.

`uv` is the one component that has no image of ours: the complete image copies it from the official `ghcr.io/astral-sh/uv`. It follows the same rule as the others, in `Toolchain image`: a run triggered by a push or by a component finishing keeps the `uv` that the `latest` image already has (its `uv.version` label), and a manual run takes the `uv_version` field, empty meaning the latest stable release of `astral-sh/uv`. The version also goes into the combination tag (`ghdl-<7>-gcc-<7>-spike-<7>-uv-<version>`). To update `uv`, run `Toolchain image` by hand with `confirm` and an empty `uv_version`.

`Toolchain image` does not wait for a component to finish: if, when it runs for a push or for the end of another component, a `GHDL image`, `GCC image` or `Spike image` run is queued or going, it skips with a notice, and the end of that run triggers it again. The last component to finish does the single assembly. A manual run of `Toolchain image` never defers.

`Toolchain image` needs the three `latest` images. If a push lands before they exist, it ends with a notice, without failing, and runs when the components finish. A manual run of it without the images fails, with a message that points at the three workflows.

## 5. Building locally

The components have no default commit, so the commit is passed to the build:

```bash
docker build -f Dockerfile.ghdl -t infra-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl 'refs/tags/v6.0.0^{}' | cut -f1)" .

docker build -f Dockerfile.gcc -t infra-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.spike -t infra-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .

docker build -t infra-toolchain \
  --build-arg GHDL_IMAGE=infra-ghdl --build-arg GCC_IMAGE=infra-gcc --build-arg SPIKE_IMAGE=infra-spike .
```

The GCC build takes from tens of minutes to over an hour, depending on the machine. Without `GHDL_IMAGE`, `GCC_IMAGE` and `SPIKE_IMAGE`, the complete image build uses the `latest` images published on GHCR. The other arguments:

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | Base image of every build (a multi-architecture image) |
| `UV_VERSION` | fixed version | Version of `uv` (only in the complete `Dockerfile`) |
| `PYTHON_VERSION` | `3.14` | Python installed by `uv` (only in the complete `Dockerfile`) |
| `COCOTB_VERSION` | `2.1.0` | cocotb installed in it (only in the complete `Dockerfile`) |

## 6. Publishing and security

The four workflows publish to `ghcr.io/<organization>/`, with the run's own `GITHUB_TOKEN`. The visibility of each package (public or private) is set in the package's settings on GitHub, not by the workflow. All four packages must be reachable by whoever will use them, and `Toolchain image` reads the other three.

The manual run of any of the four asks for the `confirm` field, which must equal the value of the `IMAGE_PUBLISH_SECRET` secret. It is the same second gate described in phase 5 of [RUNNER_SETUP.md](RUNNER_SETUP.md): write access to the repository already controls who can trigger the workflow, and the secret makes sure only someone who knows it publishes the image. The four workflows also run on a push to `main` that changes the matching `Dockerfile` or the workflow itself, and `Toolchain image` also runs after one of the three component workflows finishes. Those paths do not ask for `confirm`: the gate for a push is branch protection, and a component's run already went through its own `confirm` or its push.

To set it up, in the repository: **Settings → Secrets and variables → Actions → New repository secret**, named `IMAGE_PUBLISH_SECRET`, with any phrase as the value (for example `openssl rand -hex 32`).

## 7. Verify

```bash
docker run --rm infra-toolchain riscv32-unknown-elf-gcc --version
docker run --rm infra-toolchain riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm infra-toolchain spike --help
docker run --rm infra-toolchain ghdl --version
docker buildx imagetools inspect ghcr.io/insper-riscv/infra-gcc:latest --format '{{json .Image}}'
```

The second command should print just `.;` (one variant, the root). The last one shows, for each architecture, the GCC commit in the `riscv-gnu-toolchain.commit` label, and lists `linux/amd64` and `linux/arm64`.

## 8. Why each version

Everything is fixed by us except the packages of Ubuntu itself. The workflow that updates each fixed item is in section 4.

### 8.1 What we choose

| Item | Version | Why |
| :--- | :--- | :--- |
| Ubuntu | 26.04 LTS | the latest long-term release, a multi-architecture base (`amd64` and `arm64`), and the one GHDL 6.0.0 was built and tested on with LLVM 21 |
| GHDL | 6.0.0 | the latest stable release; the series is fixed at 6 (`SERIES` in the workflow), so 7.0.0, which is still in development, is not taken by itself |
| GHDL backend | LLVM | the `mcode` backend runs only on x86, and the same simulator must behave the same on a PC and on an ARM machine such as a Mac |
| RISC-V GCC | 16.1.0, commit `d118e53` | built from source with our own picolibc configuration (`rv32im`, `ilp32`, one variant, no CSR, no floating point hardware); follows the head of `riscv-gnu-toolchain`, because its releases are a nightly snapshot of the head, not a stable point |
| picolibc | 1.8.11 | the version the `riscv-gnu-toolchain` commit carries; compiled for the same `rv32im` as the GCC, so it has no CSR code and does floating point in software |
| Spike | commit `fdc1ffa` | the head of `riscv-isa-sim`, because its last release (`v1.1.0`) is from 2021; its debug module is moved from address `0x0` to `0x70000000` so that it does not overlap the boot ROM |
| `uv` | 0.12.23 | the latest stable release of series 0 (`UV_SERIES`); it installs Python and the dependencies of each project, and replaces `pip` and virtual environments |
| Python | 3.14.8 | the version the projects require (`>=3.14,<3.15`); the patch is the latest one the `uv` knows |
| cocotb | 2.1.0 | the first release that supports Python 3.14 and the latest; every project simulates with it, so it is in the image, and it fixes the Python version: a newer Python waits for a cocotb that supports it. On `arm64` it has no wheel and is compiled, hence `g++` |
| GTKWave (`dev_tools`) | 3.3.116 | the latest stable release of series 3 (`SERIES`); the 4.0.0 line is a pre-alpha with no release. Built from the GTK 3 tree, which has a Wayland backend |

### 8.2 What comes from Ubuntu

| Item | Version | Why it is in the image |
| :--- | :--- | :--- |
| LLVM | 21.1.8 | the library the GHDL LLVM backend links against; it is the one `llvm-dev` installs on 26.04, and the one GHDL 6.0.0 was tested with here (LLVM 22 is available and was not tested) |
| `gcc` and `g++` (host) | 15.2.0 | link the executable GHDL elaborates, and compile cocotb on `arm64`; the RISC-V GCC keeps its own `riscv32-unknown-elf-` names, so they do not clash |
| `git`, `make`, `curl` | 2.53.0, 4.4.1, 8.18.0 | the checkout of a workflow, the installers and the `make` of the projects |
| GTK 3 (`dev_tools`) | 3.24.52 | what GTKWave runs on, with its Wayland and X11 backends |
| `gnat` (`dev_tools`) | 14 | the Ada runtime and compiler for building GHDL or Ada code in the development environment |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
