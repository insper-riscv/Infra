# Toolchain Docker image

A Docker image with everything the RISC-V test flow needs except Quartus: GHDL, the RISC-V GCC with picolibc, Spike and `uv`. The `Dockerfile` at the root of this repository builds it, and the `toolchain image` workflow publishes it to the GitHub Container Registry.

## 1. What the image contains

| Component | Detail | Path |
| :--- | :--- | :--- |
| GHDL | mcode backend, inherited from the `ghdl/ghdl` base image | `/opt/ghdl` |
| RISC-V GCC | `rv32im`/`ilp32` target with picolibc, a single library variant (what [GCC_SETUP.md](GCC_SETUP.md) builds) | `/opt/riscv-foundation/riscv32-elf` |
| Spike | With its debug module moved from address `0x0` to `0x70000000` (what [SPIKE_SETUP.md](SPIKE_SETUP.md) builds) | `/opt/riscv-foundation/spike` |
| `uv` | Python project manager | `/usr/local/bin` |

The GCC and Spike binaries are already on the image's `PATH`. Each install keeps in `.tag` the commit it was built from.

Quartus is not in the image, and a container cannot see the USB-Blaster without extra host configuration. The real-hardware tests keep running on the self-hosted runner described in [RUNNER_SETUP.md](RUNNER_SETUP.md).

## 2. Using the image

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

## 3. Building locally

```bash
docker build -t infra-toolchain .
```

The build compiles the GCC, which takes from tens of minutes to over an hour, depending on the machine. The build arguments pin what is compiled:

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `RISCV_GNU_TOOLCHAIN_COMMIT` | fixed commit | Commit of `riscv-collab/riscv-gnu-toolchain` to build |
| `RISCV_ISA_SIM_COMMIT` | fixed commit | Commit of `riscv-software-src/riscv-isa-sim` to build |
| `GHDL_IMAGE` | `ghdl/ghdl:6.0.0-mcode-ubuntu-24.04` | Base image, which brings GHDL |
| `UV_VERSION` | fixed version | Version of `uv` |

For example, to build another Spike commit:

```bash
docker build --build-arg RISCV_ISA_SIM_COMMIT=<commit> -t infra-toolchain .
```

## 4. Publishing

The `.github/workflows/toolchain-image.yml` workflow runs on every push to `main` that changes the `Dockerfile` or the workflow itself, and on demand (`workflow_dispatch`). It:

1. Builds the image with the GitHub Actions layer cache.
2. Checks the image before publishing: GHDL, GCC with picolibc, a single library variant, Spike without the debug module overlap, and `uv`.
3. Publishes to `ghcr.io/<organization>/infra-toolchain` with the tags `latest` and `sha-<commit>`.

The package's visibility (public or private) is set in the package's settings on GitHub, not by the workflow.

### 4.1. Manual run

The manual run (Actions → `toolchain image` → **Run workflow**) asks for the `confirm` field, which must equal the value of the `IMAGE_PUBLISH_SECRET` secret. It is the same second gate described in phase 5 of [RUNNER_SETUP.md](RUNNER_SETUP.md): write access to the repository already controls who can trigger the workflow, and the secret makes sure only someone who knows it publishes the image. A push to `main` skips this check, because branch protection is the gate for that path.

To set it up, in the repository: **Settings → Secrets and variables → Actions → New repository secret**, named `IMAGE_PUBLISH_SECRET`, with any phrase as the value (for example `openssl rand -hex 32`).

## 5. Verify

```bash
docker run --rm infra-toolchain riscv32-unknown-elf-gcc --version
docker run --rm infra-toolchain riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm infra-toolchain spike --help
docker run --rm infra-toolchain ghdl --version
```

The second command should print just `.;` (one variant, the root).

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
