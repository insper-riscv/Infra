# Toolchain Docker images

Three Docker images with what the RISC-V test flow needs except Quartus: one with just the GCC, one with just Spike, and a complete one (GHDL, the RISC-V GCC with picolibc, Spike and `uv`) that copies the artifacts of the first two. The `Dockerfile`s are at the root of this repository, and three workflows publish the images to the GitHub Container Registry.

## 1. The three images

| Image | `Dockerfile` | Workflow | Contents | Tags |
| :--- | :--- | :--- | :--- | :--- |
| `ghcr.io/<organization>/infra-gcc` | `Dockerfile.gcc` | `GCC image` | Just `/opt/riscv-foundation/riscv32-elf` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-spike` | `Dockerfile.spike` | `Spike image` | Just `/opt/riscv-foundation/spike` | `<commit>` and `latest` |
| `ghcr.io/<organization>/infra-toolchain` | `Dockerfile` | `Toolchain image` | The complete image | `latest`, `sha-<Infra commit>` and `gcc-<first 7>-spike-<first 7>` |

The `<commit>` of the first two is the commit of `riscv-collab/riscv-gnu-toolchain` and of `riscv-software-src/riscv-isa-sim` they were built from, and it is also in the image's `riscv-gnu-toolchain.commit` or `riscv-isa-sim.commit` label. The component images have no file system besides those directories, so they cannot be run: they exist to be copied from.

## 2. What the complete image contains

| Component | Detail | Path |
| :--- | :--- | :--- |
| GHDL | mcode backend, inherited from the `ghdl/ghdl` base image | `/opt/ghdl` |
| RISC-V GCC | `rv32im`/`ilp32` target with picolibc, a single library variant (what [GCC_SETUP.md](GCC_SETUP.md) builds) | `/opt/riscv-foundation/riscv32-elf` |
| Spike | With its debug module moved from address `0x0` to `0x70000000` (what [SPIKE_SETUP.md](SPIKE_SETUP.md) builds) | `/opt/riscv-foundation/spike` |
| `uv` | Python project manager | `/usr/local/bin` |

The GCC and Spike binaries are already on the image's `PATH`. Each install keeps in `.tag` the commit it was built from, and the complete image carries both commit labels.

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

## 4. Updating the GCC or Spike

Each component has a manually run workflow. In Actions, pick `GCC image` or `Spike image` and click **Run workflow**, filling in:

| Field | Meaning |
| :--- | :--- |
| `confirm` | The value of the `IMAGE_PUBLISH_SECRET` secret (see section 6) |
| `commit` | The commit to build. Empty: the latest of the project's default branch |
| `force` | Rebuild and republish even if the image for that commit already exists |

The workflow resolves the commit, checks whether `infra-gcc:<commit>` (or `infra-spike:<commit>`) already exists and, if it does and `force` is off, builds nothing. Otherwise it builds, checks the install and publishes it with the tags `<commit>` and `latest`.

Both component workflows also run by themselves on a push to `main` that changes their own `Dockerfile.gcc` or `Dockerfile.spike`, or the workflow itself. There is no `commit` field then: they rebuild the commit the `latest` image already has (the recipe changed, not the version) with `force` on, and only use the latest upstream commit when nothing is published yet. So the merge that adds the three `Dockerfile`s already publishes the two components for the first time.

When one of these workflows finishes successfully, `Toolchain image` runs by itself: it reads the commits from the labels of the two `latest` images and assembles and publishes a new complete image. Updating just Spike takes a few minutes, and updating the GCC takes from tens of minutes to over an hour.

`Toolchain image` does not wait for a component to finish: if, when it runs for a push or for the end of another component, a `GCC image` or `Spike image` run is queued or going, it skips with a notice, and the end of that run triggers it again. The last component to finish does the single assembly. A manual run of `Toolchain image` never defers.

`Toolchain image` needs both `latest` images. If a push lands before they exist, it ends with a notice, without failing, and runs when the components finish. A manual run of it without the images fails, with a message that points at the two workflows.

## 5. Building locally

The components have no default commit, so the commit is passed to the build:

```bash
docker build -f Dockerfile.gcc -t infra-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.spike -t infra-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .

docker build -t infra-toolchain \
  --build-arg GCC_IMAGE=infra-gcc --build-arg SPIKE_IMAGE=infra-spike .
```

The GCC build takes from tens of minutes to over an hour, depending on the machine. Without `GCC_IMAGE` and `SPIKE_IMAGE`, the complete image build uses the `latest` images published on GHCR. The other arguments:

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `GHDL_IMAGE` | `ghdl/ghdl:6.0.0-mcode-ubuntu-24.04` | Base image, which brings GHDL |
| `UV_VERSION` | fixed version | Version of `uv` (only in the complete `Dockerfile`) |

## 6. Publishing and security

The three workflows publish to `ghcr.io/<organization>/`, with the run's own `GITHUB_TOKEN`. The visibility of each package (public or private) is set in the package's settings on GitHub, not by the workflow. All three packages must be reachable by whoever will use them, and `Toolchain image` reads the other two.

The manual run of any of the three asks for the `confirm` field, which must equal the value of the `IMAGE_PUBLISH_SECRET` secret. It is the same second gate described in phase 5 of [RUNNER_SETUP.md](RUNNER_SETUP.md): write access to the repository already controls who can trigger the workflow, and the secret makes sure only someone who knows it publishes the image. The three workflows also run on a push to `main` that changes the matching `Dockerfile` or the workflow itself, and `Toolchain image` also runs after one of the two component workflows finishes. Those paths do not ask for `confirm`: the gate for a push is branch protection, and a component's run already went through its own `confirm` or its push.

To set it up, in the repository: **Settings → Secrets and variables → Actions → New repository secret**, named `IMAGE_PUBLISH_SECRET`, with any phrase as the value (for example `openssl rand -hex 32`).

## 7. Verify

```bash
docker run --rm infra-toolchain riscv32-unknown-elf-gcc --version
docker run --rm infra-toolchain riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm infra-toolchain spike --help
docker run --rm infra-toolchain ghdl --version
docker buildx imagetools inspect ghcr.io/insper-riscv/infra-gcc:latest --format '{{json .Image.Config.Labels}}'
```

The second command should print just `.;` (one variant, the root). The last one shows the GCC commit in the `riscv-gnu-toolchain.commit` label.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
