# Infra

🌐 [Português](README.md) · [English](README.en.md)

The infrastructure of the RV32 project: the Docker images with the tools of the tests, the step by step guides to install those tools by hand, and the guides to set up a workstation with FPGA hardware as a self-hosted GitHub Actions runner. The guides cover Debian-like (`apt`) and RHEL-like (`dnf`/`yum`) distros.

## 1. Which guide to follow

| I want to | Read |
| :--- | :--- |
| use the tools without installing them, in CI or in a Dev Container | [Docker images](docs/en/docker/README.md) |
| install the tools directly on a machine | [Manual installation](docs/en/manual/README.md) |
| install Quartus Prime Lite on a workstation | [QUARTUS_INSTALL.md](docs/en/QUARTUS_INSTALL.md) |
| set up a workstation with an FPGA board as a runner | [RUNNER_SETUP.md](docs/en/RUNNER_SETUP.md) |

A workstation with a board follows [QUARTUS_INSTALL.md](docs/en/QUARTUS_INSTALL.md) and then [RUNNER_SETUP.md](docs/en/RUNNER_SETUP.md), which needs Docker because the jobs run in the CI images.

## 2. The images

The images come in three kinds, described in the [overview of the images](docs/en/docker/README.md), which also has the file of each one.

| Image | Holds |
| :--- | :--- |
| `base-*` | one tool each: GHDL, Yosys with SymbiYosys, the RISC-V GCC, picolibc, Spike, Sail and GTKWave |
| `ci-vhdl` | GHDL, Yosys, `uv`, Python and cocotb, for the VHDL tests |
| `ci-asm` | the above plus the RISC-V GCC with picolibc and Spike, for the assembly and C tests |
| `ci-elf` | the above plus Sail and the dependencies of ACT4, for the ELF tests |
| `dev_tools` | the above plus GTKWave and the user `dev`, for the Dev Container |

Every image is published to `ghcr.io/insper-riscv` for `linux/amd64` and `linux/arm64`, and a daily workflow of each base image looks for a new version of its tool.

## 3. The repository

| Path | Content |
| :--- | :--- |
| `Dockerfile.*` | the recipe of each image |
| `.github/workflows/` | one workflow per image, the shared build, the warning about changed recipes and the cleanup of old versions |
| `.github/scripts/` | the choice of the latest upstream commit whose CI passed, with its test |
| `scripts/` | the cleanup of old versions of the packages |
| `docs/` | the guides, in `en/` and `pt-br/` |

## 4. Contributing

- [CONTRIBUTING.en.md](CONTRIBUTING.en.md): the rules of contribution and the verification before opening a Pull Request.
- [AUTHORS.en.md](AUTHORS.en.md): the authors with commits in the repository.
- [CITATION.cff](CITATION.cff): the metadata to cite the software.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
