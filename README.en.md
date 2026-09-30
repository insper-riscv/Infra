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
  + JTAG). Without it, there is no way to run `Testes`' real-hardware
  tests.
- **[GCC_SETUP.md](docs/en/GCC_SETUP.md)**: builds the RISC-V GCC
  (binutils, compiler, picolibc, gdb) for the `rv32im` target. Without it,
  there is no way to compile the C test programs that `Testes` and `Tools`
  use.
- **[SPIKE_SETUP.md](docs/en/SPIKE_SETUP.md)**: builds Spike, the
  RISC-V reference simulator. Without it, `Testes`' memory tests have no
  reference golden to compare against.

Together, these docs are the foundation that `RV32IM`, `Testes` and
`Tools` depend on to work as intended.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
