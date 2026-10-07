# Infra

🌐 [Português](README.md) · [English](README.en.md)

Documentation of the requirements and of how to install and configure the
organization's infrastructure (workstations with FPGA hardware, self-hosted
GitHub Actions runners, shared tooling), made for Debian-like (`apt`) and
RHEL-like (`dnf`/`yum`) distros.

## Docs

- [QUARTUS_INSTALL.md](docs/en/QUARTUS_INSTALL.md): install Quartus Prime
  Lite globally on a workstation (runner prerequisite).
- [RUNNER_SETUP.md](docs/en/RUNNER_SETUP.md): configure a self-hosted
  GitHub Actions runner with access to FPGA hardware (Quartus + JTAG).
- [SPIKE_SETUP.md](docs/en/SPIKE_SETUP.md): install `uv` globally and build
  the RISC-V reference simulator into the shared cache, on `apt` and
  `dnf`/`yum` distros.
- [GCC_SETUP.md](docs/en/GCC_SETUP.md): build the RISC-V GCC from source
  into the same shared cache, on `apt` and `dnf`/`yum` distros.
- [TOOLCHAIN_IMAGE.md](docs/en/TOOLCHAIN_IMAGE.md): Docker images of the
  RISC-V GCC (picolibc), of Spike and a complete one with GHDL, the GCC, Spike
  and `uv`, built and published by CI, for anyone who does not want to install
  them on a machine.
- [DEVTOOLS_IMAGE.md](docs/en/DEVTOOLS_IMAGE.md): `dev_tools`, the toolchain
  image plus the user `dev`, Python, GTKWave (native Wayland) and the build tools, for a Dev
  Container.

## Suggested order

Each doc already links to its own prerequisites, but the natural order for a
new workstation is:

1. [QUARTUS_INSTALL.md](docs/en/QUARTUS_INSTALL.md)
2. [RUNNER_SETUP.md](docs/en/RUNNER_SETUP.md)
3. [GCC_SETUP.md](docs/en/GCC_SETUP.md)
4. [SPIKE_SETUP.md](docs/en/SPIKE_SETUP.md)

## Scope

- **[QUARTUS_INSTALL.md](docs/en/QUARTUS_INSTALL.md)**: installs
  Quartus Prime Lite globally on the workstation. Without it, there is no
  way to synthesize or program the hardware that `RV32IM` implements.
- **[RUNNER_SETUP.md](docs/en/RUNNER_SETUP.md)**: configures a
  self-hosted GitHub Actions runner with access to FPGA hardware (Quartus
  + JTAG), with Docker for the toolchain image. Without it, there is no way
  to run `Tests`' real-hardware tests.
- **[GCC_SETUP.md](docs/en/GCC_SETUP.md)**: builds the RISC-V GCC
  (binutils, compiler, picolibc, gdb) for the `rv32im` target. It is what the
  [toolchain image](docs/en/TOOLCHAIN_IMAGE.md) is built from; install it on a
  workstation only to compile outside the image.
- **[SPIKE_SETUP.md](docs/en/SPIKE_SETUP.md)**: builds Spike, the
  RISC-V reference simulator. Like the GCC, it is in the toolchain image; the
  setup is for running it outside the image.

Together, these docs are the foundation that `RV32`, `Tests` and
`Tools` depend on to work as intended.

## What the images contain

Both are published for `linux/amd64` and `linux/arm64`, with the same versions on each, and
`dev_tools` is the toolchain image plus what is listed under it. How each item is updated is in
[TOOLCHAIN_IMAGE.md](docs/en/TOOLCHAIN_IMAGE.md) and [DEVTOOLS_IMAGE.md](docs/en/DEVTOOLS_IMAGE.md).

### Toolchain image (`ghcr.io/insper-riscv/infra-toolchain`)

| Item | Version |
| :--- | :--- |
| Ubuntu | 26.04 LTS |
| GHDL (LLVM backend) | 6.0.0 |
| LLVM (library the GHDL backend runs on) | 21.1.8 |
| RISC-V GCC (`rv32im`, `ilp32`: no CSR, no F or D) | 16.1.0 (`riscv-gnu-toolchain` commit `d118e53`) |
| picolibc (C library of the RISC-V GCC, one variant for the same `rv32im`: no CSR, floating point in software) | 1.8.11 |
| Spike | 1.1.1-dev (`riscv-isa-sim` commit `fdc1ffa`, debug module at `0x70000000`) |
| `uv` | 0.12.23 |
| Python | 3.14.8 |
| cocotb | 2.1.0 |
| `gcc` and `g++` (host) | 15.2.0 |
| `git` | 2.53.0 |
| `make` | 4.4.1 |
| `curl` | 8.18.0 |

### Dev tools image (`ghcr.io/insper-riscv/dev_tools`)

Everything in the toolchain image, plus:

| Item | Version |
| :--- | :--- |
| GTKWave (GTK 3 tree, Wayland and X11) | 3.3.116 |
| GTK 3 | 3.24.52 |
| `gnat` | 14 |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
