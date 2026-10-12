# Toolchain Docker images

Docker images with what the RISC-V test flow needs except Quartus: one for each component (GHDL, the GCC, picolibc, Spike, and Yosys with SymbiYosys) and a complete one (those, plus `uv`, Python and cocotb) that copies the artifacts of the components. The `Dockerfile`s are at the root of this repository, and one workflow per image publishes them to the GitHub Container Registry. Every image is published for `linux/amd64` and `linux/arm64`, and the two architectures hold the same versions of the same tools: GHDL has the LLVM backend on both, so a simulation behaves the same on a PC and on an ARM machine such as a Mac.

## 1. The images

| Image | `Dockerfile` | Workflow | Contents | Tags |
| :--- | :--- | :--- | :--- | :--- |
| `ghcr.io/<organization>/infra-ghdl` | `Dockerfile.ghdl` | `GHDL image` | Just `/opt/ghdl` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-gcc` | `Dockerfile.gcc` | `GCC image` | Just `/opt/riscv-foundation/riscv32-elf` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-picolibc` | `Dockerfile.picolibc` | `Picolibc image` | Just the files picolibc installs into the GCC's sysroot, under `/opt/riscv-foundation/riscv32-elf` | `<picolibc commit>-<GCC commit>` and `latest` |
| `ghcr.io/<organization>/infra-spike` | `Dockerfile.spike` | `Spike image` | Just `/opt/riscv-foundation/spike` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-yosys` | `Dockerfile.yosys` | `Yosys image` | Just `/opt/yosys` (Yosys and SymbiYosys) | `<Yosys commit>-<sby commit>` and `latest` |
| `ghcr.io/<organization>/infra-toolchain` | `Dockerfile` | `Toolchain image` | The complete image | `latest`, `sha-<Infra commit>` and `ghdl-<first 7>-gcc-<first 7>-spike-<first 7>-yosys-<first 7>-sby-<first 7>-uv-<version>` |

The `<commit>` of the first three is the commit of `ghdl/ghdl` (the release tag's), `riscv-collab/riscv-gnu-toolchain` and `riscv-software-src/riscv-isa-sim` they were built from, and it is also in the image's `ghdl.commit`, `riscv-gnu-toolchain.commit` or `riscv-isa-sim.commit` label. The component images have no file system besides those directories, so they cannot be run: they exist to be copied from.

Every image carries the labels `org.opencontainers.image.title`, `description`, `source`, `revision` (the commit of this repository that built it) and `created` (when it was built), set by the workflow, and the commit labels of its components (`ghdl.commit`, `riscv-gnu-toolchain.commit`, `riscv-isa-sim.commit`, `gtkwave.commit`, `uv.version`). They are set explicitly because an image built on the Ubuntu base would otherwise inherit the title, the description and the date of the Ubuntu image.

## 2. What the complete image contains

| Component | Detail | Path |
| :--- | :--- | :--- |
| GHDL | LLVM backend, built from source (the mcode backend of the `ghdl/ghdl` images is x86 only, and the two architectures must run the same GHDL) | `/opt/ghdl` |
| RISC-V GCC | `rv32im`/`ilp32` target a single library variant (what [GCC_SETUP.md](GCC_SETUP.md) builds) | `/opt/riscv-foundation/riscv32-elf` |
| picolibc | The C library of that GCC, rebuilt from its own image over the one the GCC image carries (same sysroot, same single `rv32im`/`ilp32` variant) | `/opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf` |
| Spike | With its debug module moved from address `0x0` to `0x70000000` (what [SPIKE_SETUP.md](SPIKE_SETUP.md) builds) | `/opt/riscv-foundation/spike` |
| `uv` | Python project manager | `/usr/local/bin` |
| Python | 3.14, installed by `uv` for every user, with `python3` and `python` on the `PATH` | `/opt/uv/python` |
| cocotb | 2.1.0, installed in that Python | `/opt/uv/python` |
| Yosys | 0.69, built from source; reads the Verilog netlist GHDL synthesizes from the VHDL | `/opt/yosys` |
| SymbiYosys (`sby`) | v0.69, built from source with Yosys; runs Yosys and the solvers | `/opt/yosys` |
| `z3` and `boolector` | the SMT solvers SymbiYosys uses, from Ubuntu | `/usr/bin` |

GHDL, the GCC and Spike are already on the image's `PATH`. The host `gcc` is in the image too, because the LLVM backend links the design it elaborates with it; the RISC-V one keeps its own `riscv32-unknown-elf-` names. With the LLVM backend `ghdl -r` needs a prior `ghdl -e` (or use `ghdl --elab-run`); the Makefiles and the simulation runner already do. Each install keeps in `.tag` the commit it was built from, and the complete image carries the three commit labels.

Python is pinned to 3.14 because that is the version the projects require (`>=3.14,<3.15`), and cocotb 2.1.0 is the first release that supports it: cocotb is what fixes the Python version, so a newer Python waits for a cocotb that supports it (the build arguments `PYTHON_VERSION` and `COCOTB_VERSION` change both together). Every project simulates with cocotb, so it is in the image (cocotb 2.1.0 has wheels for Python 3.14 on Linux x86-64, macOS and Windows but not on Linux arm64, so on arm64 it is compiled, which is why the image has `g++`, and a project's `uv sync` compiles it there too); the other Python libraries are each project's own and come from its `uv sync`, which finds this Python instead of downloading one.

Quartus is in none of the images. The complete image has the system library the command-line tools of a Quartus installation link against (`libglib2.0-0t64`), so an installation on the host can be mounted into it and run there (section 3.1). The real-hardware tests of a project split the work: the test ROMs and their goldens are built inside the complete image, and Quartus and the JTAG cable are used from the self-hosted runner described in [RUNNER_SETUP.md](RUNNER_SETUP.md), which needs Docker and access to it.

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

### 3.1. Quartus from the host

The Quartus of the host (here `/opt/altera_lite/25.1std`) is mounted read-only and put on the `PATH` inside the container. The USB-Blaster is reached through the JTAG server (`jtagd`) of the host, which the container sees by sharing the host network:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp/h \
  -v "$PWD:/workspace" -v /opt/altera_lite:/opt/altera_lite:ro \
  ghcr.io/insper-riscv/infra-toolchain:latest bash -c '
    export PATH=/opt/altera_lite/25.1std/quartus/bin:$PATH
    jtagconfig
    cd platforms/sdram-bringup/quartus && quartus_sh --flow compile sdram_bringup'
```

| Option | Why |
| :--- | :--- |
| `-v /opt/altera_lite:/opt/altera_lite:ro` | the Quartus installation, read-only; the image carries none |
| `--network host` | `jtagd` listens on `localhost:1309` of the host, and the programmer and `quartus_stp` of the container connect to it there |
| `--user "$(id -u):$(id -g)"` and `-e HOME=/tmp/h` | the files the build writes belong to the invoking user, and Quartus has a writable home |

`jtagd` must be running on the host, and it can stop on its own between two uses. Run `jtagconfig` on the host right before the container: it starts `jtagd` if none is running. Without a `jtagd` on the host, the container starts one of its own, which cannot see the USB, and `jtagconfig` inside the container prints:

```text
1) USB-Blaster variant [3-5]
  Unable to lock chain - Bad port name
```

With the host `jtagd` running, the same command prints the cable and the chip (`USB-Blaster [3-5]`, `02B050DD 5CE(BA4|FA4)` on the DE0-CV). On a Docker daemon with user-namespace remapping, `--network host` is refused unless the run also has `--userns=host`.

### 3.2. Formal verification

GHDL turns a VHDL entity into a Verilog netlist, which Yosys reads and SymbiYosys proves properties on. The properties are written in SystemVerilog around the netlist, so no GHDL plugin for Yosys is needed:

```bash
ghdl -a --std=08 --workdir=work my_block.vhd
ghdl --synth --std=08 --workdir=work --out=verilog my_block > my_block.v
sby -f my_block.sby
```

The `.sby` file names the mode (`prove` for an unbounded proof by induction, `bmc` for a bounded check, `cover` to confirm the properties are not vacuous), the depth, the engine (`smtbmc z3`) and the files. A proof that fails writes a waveform of the counterexample next to the log.

## 4. Updating GHDL, the GCC or Spike

Each component has a manually run workflow. In Actions, pick `GHDL image`, `GCC image`, `Picolibc image`, `Spike image` or `Yosys image` and click **Run workflow**, filling in:

| Field | Meaning |
| :--- | :--- |
| `confirm` | The value of the `IMAGE_PUBLISH_SECRET` secret (see section 6) |
| `commit` | The commit to build. Empty: the latest of the project's default branch (for GHDL, the commit of its latest release tag) |
| `force` | Rebuild and republish even if the image for that commit already exists |

The `Picolibc image` takes a picolibc `commit` (empty: the latest release tag of the series set in `SERIES`, `1`, so `1.x.y`) and builds it with the GCC of the latest GCC image; it also runs by itself when the `GCC image` finishes, because the library is compiled by that GCC, and then keeps the picolibc commit it already has. Updating picolibc alone takes minutes, and the `Toolchain image` assembles the new complete image from it without rebuilding the GCC.

The `Yosys image` has one more field, `sby_commit` (empty: the `sby` tag with the same version as the Yosys release), because the image holds both and the `commit` field is the Yosys commit. Its empty `commit` takes the latest release tag of the series set in `SERIES` (`0`, so `v0.N`, never a moving branch).

The workflow resolves the commit, checks whether `infra-gcc:<commit>` (or `infra-spike:<commit>`, or `infra-picolibc:<picolibc commit>-<GCC commit>`, or `infra-yosys:<Yosys commit>-<sby commit>`) already exists and, if it does and `force` is off, builds nothing. Otherwise it builds, checks the install and publishes it with the tags `<commit>` and `latest`.

The component workflows also run by themselves on a push to `main` that changes their own `Dockerfile.ghdl`, `Dockerfile.gcc`, `Dockerfile.picolibc`, `Dockerfile.spike` or `Dockerfile.yosys`, or the workflow itself. There is no `commit` field then: they rebuild the commit the `latest` image already has (the recipe changed, not the version) with `force` on, and only use the latest upstream commit when nothing is published yet. So the merge that adds the `Dockerfile`s already publishes the components for the first time.

When one of these workflows finishes successfully, `Toolchain image` runs by itself: it reads the commits from the labels of the three `latest` images and assembles and publishes a new complete image. Updating just Spike takes a few minutes, and updating the GCC or GHDL takes from tens of minutes to over an hour.

Each architecture is built on a runner of its own (`ubuntu-26.04` for `linux/amd64` and `ubuntu-24.04-arm` for `linux/arm64`): the GCC and GHDL builds take hours under emulation. A final job joins the two images into one manifest with the tags, so `docker pull` gives each machine its own.

`uv` is the one component that has no image of ours: the complete image copies it from the official `ghcr.io/astral-sh/uv`. It follows the same rule as the others, in `Toolchain image`: a run triggered by a push or by a component finishing keeps the `uv` that the `latest` image already has (its `uv.version` label), and a manual run takes the `uv_version` field, empty meaning the latest stable release of `astral-sh/uv`. The version also goes into the combination tag (`ghdl-<7>-gcc-<7>-spike-<7>-uv-<version>`). To update `uv`, run `Toolchain image` by hand with `confirm` and an empty `uv_version`.

`Toolchain image` does not wait for a component to finish: if, when it runs for a push or for the end of another component, a `GHDL image`, `GCC image`, `Picolibc image`, `Spike image` or `Yosys image` run is queued or going, it skips with a notice, and the end of that run triggers it again. The last component to finish does the single assembly. A manual run of `Toolchain image` never defers.

`Toolchain image` needs the `latest` image of every component. If a push lands before they exist, it ends with a notice, without failing, and runs when the components finish. A manual run of it without the images fails, with a message that points at the component workflows.

## 5. Building locally

The components have no default commit, so the commit is passed to the build:

```bash
docker build -f Dockerfile.ghdl -t infra-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl 'refs/tags/v6.0.0^{}' | cut -f1)" .

docker build -f Dockerfile.gcc -t infra-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.picolibc -t infra-picolibc \
  --build-arg GCC_IMAGE=infra-gcc \
  --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
  --build-arg GCC_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.spike -t infra-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .

docker build -f Dockerfile.yosys -t infra-yosys \
  --build-arg YOSYS_COMMIT="$(git ls-remote https://github.com/YosysHQ/yosys 'refs/tags/v0.69^{}' | cut -f1)" \
  --build-arg SBY_COMMIT="$(git ls-remote https://github.com/YosysHQ/sby 'refs/tags/v0.69^{}' | cut -f1)" .

docker build -t infra-toolchain \
  --build-arg GHDL_IMAGE=infra-ghdl --build-arg GCC_IMAGE=infra-gcc --build-arg PICOLIBC_IMAGE=infra-picolibc --build-arg SPIKE_IMAGE=infra-spike \
  --build-arg YOSYS_IMAGE=infra-yosys .
```

The GCC build takes from tens of minutes to over an hour, depending on the machine. Without `GHDL_IMAGE`, `GCC_IMAGE`, `PICOLIBC_IMAGE`, `SPIKE_IMAGE` and `YOSYS_IMAGE`, the complete image build uses the `latest` images published on GHCR. The other arguments:

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | Base image of every build (a multi-architecture image) |
| `UV_VERSION` | fixed version | Version of `uv` (only in the complete `Dockerfile`) |
| `PYTHON_VERSION` | `3.14` | Python installed by `uv` (only in the complete `Dockerfile`) |
| `COCOTB_VERSION` | `2.1.0` | cocotb installed in it (only in the complete `Dockerfile`) |

## 6. Publishing and security

The image workflows publish to `ghcr.io/<organization>/`, with the run's own `GITHUB_TOKEN`. The visibility of each package (public or private) is set in the package's settings on GitHub, not by the workflow. All the packages must be reachable by whoever will use them, and `Toolchain image` reads the component packages.

The manual run of any of the image workflows asks for the `confirm` field, which must equal the value of the `IMAGE_PUBLISH_SECRET` secret. It is the same second gate described in phase 5 of [RUNNER_SETUP.md](RUNNER_SETUP.md): write access to the repository already controls who can trigger the workflow, and the secret makes sure only someone who knows it publishes the image. They also run on a push to `main` that changes the matching `Dockerfile` or the workflow itself, and `Toolchain image` also runs after one of the component workflows finishes. Those paths do not ask for `confirm`: the gate for a push is branch protection, and a component's run already went through its own `confirm` or its push.

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
| picolibc | 1.8.12 | the latest release of series 1 (`SERIES` in the workflow), built from its own image with the GCC of the GCC image, so a new picolibc does not need a new GCC build. The libstdc++ of the GCC image stays linked to the headers of the picolibc the GCC was built with; it is compiled with the options of the build `riscv-gnu-toolchain` runs for it (meson, minimum size, installed into the sysroot) |
| Spike | commit `fdc1ffa` | the head of `riscv-isa-sim`, because its last release (`v1.1.0`) is from 2021; its debug module is moved from address `0x0` to `0x70000000` so that it does not overlap the boot ROM |
| `uv` | 0.13.0 | the latest stable release of series 0 (`UV_SERIES`); it installs Python and the dependencies of each project, and replaces `pip` and virtual environments |
| Python | 3.14.8 | the version the projects require (`>=3.14,<3.15`); the patch is the latest one the `uv` knows |
| cocotb | 2.1.0 | the first release that supports Python 3.14 and the latest; every project simulates with it, so it is in the image, and it fixes the Python version: a newer Python waits for a cocotb that supports it. On `arm64` it has no wheel and is compiled, hence `g++` |
| Yosys | 0.69 | the latest release of series 0 (`SERIES` in the workflow), built from source because Ubuntu 26.04 has the older 0.52; the newer release avoids merging formal properties (`opt_merge`, since 0.61) and goes with the same-numbered `sby`. The Slang-based SystemVerilog front-end is left out of the build |
| SymbiYosys (`sby`) | v0.69 | released in step with Yosys (`v0.N` of one with `v0.N` of the other), so the image takes the tag with the Yosys version. It imports `click`, which `uv` installs into the image's Python (8.5.0) |
| GTKWave (`dev_tools`) | 3.3.116 | the latest stable release of series 3 (`SERIES`); the 4.0.0 line is a pre-alpha with no release. Built from the GTK 3 tree, which has a Wayland backend |

### 8.2 What comes from Ubuntu

| Item | Version | Why it is in the image |
| :--- | :--- | :--- |
| LLVM | 21.1.8 | the library the GHDL LLVM backend links against; it is the one `llvm-dev` installs on 26.04, and the one GHDL 6.0.0 was tested with here (LLVM 22 is available and was not tested) |
| `gcc` and `g++` (host) | 15.2.0 | link the executable GHDL elaborates, and compile cocotb on `arm64`; the RISC-V GCC keeps its own `riscv32-unknown-elf-` names, so they do not clash |
| `git` | 2.53.0 | the checkout of a workflow |
| `make` | 4.4.1 | the Makefiles of the projects and ACT4's own `make` |
| `curl` | 8.18.0 | installers and downloads |
| `libglib2.0-0t64` | 2.88.0 | `libglib-2.0` and `libgthread-2.0`, which the command-line tools of a Quartus installation mounted from the host link against |
| `libreadline8t64`, `libtcl8.6` and `libffi8` | 8.3, 8.6.17 and 3.5.2 | the libraries the Yosys of the image links against |
| `z3` | 4.13.3 | the SMT solver SymbiYosys runs by default |
| `boolector` | 1.5.118 | a second SMT solver SymbiYosys can use |
| GTK 3 (`dev_tools`) | 3.24.52 | what GTKWave runs on, with its Wayland and X11 backends |
| `gnat` (`dev_tools`) | 14 | the Ada runtime and compiler for building GHDL or Ada code in the development environment |

## 9. Cleaning old versions

Every publication adds versions to the package and none is removed by a workflow of ours. `scripts/cleanup-images.sh` deletes the old ones and keeps what the tag `latest` reaches: the manifest tagged `latest` and every manifest below it (the image of each architecture and its attestation). Those manifests have no tag of their own and are what keeps `latest` pullable, so a plain "delete the untagged versions" would break it. Everything else is deleted, tagged or not, including the tags of earlier commits.

```bash
scripts/cleanup-images.sh                        # every package, only listing
scripts/cleanup-images.sh infra-gcc dev_tools    # only these, only listing
scripts/cleanup-images.sh --delete infra-gcc     # really deletes
```

| Safeguard | What it does |
| :--- | :--- |
| Listing first | it deletes only with `--delete` (the workflow: the `delete` field, off by default) |
| Minimum age | a version younger than `MIN_AGE_MINUTES` (120 by default) is never deleted, because a publication pushes the image of each architecture without a tag and tags the manifest above them only at the end |
| No `latest` | a package with no version tagged `latest`, or whose manifest cannot be read, is left untouched |
| Missing manifest | a manifest that `latest` references and that is no longer in the registry is reported as a warning and does not stop the run |

The workflow `Clean up old image versions` runs it by hand, with the same `confirm` field as the publications. With `delete` on it also refuses to run while any image workflow is queued or running.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
