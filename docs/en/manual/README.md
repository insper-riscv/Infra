# Manual installation

Step by step to install the tools of the infrastructure directly on a machine, without Docker. Each guide builds or installs one tool in the same directory the Docker images use, so a machine installed by hand and an image hold the same layout.

| Guide | Installs | Directory |
| :--- | :--- | :--- |
| [GCC_SETUP.md](GCC_SETUP.md) | The RISC-V GCC, binutils, GDB and picolibc, for the variants of the images | `/opt/riscv-foundation/riscv32-elf` |
| [SPIKE_SETUP.md](SPIKE_SETUP.md) | `uv` globally and the RISC-V reference simulator | `/opt/riscv-foundation/spike` |
| [GHDL_SETUP.md](GHDL_SETUP.md) | GHDL with the LLVM backend | `/opt/ghdl` |
| [YOSYS_SETUP.md](YOSYS_SETUP.md) | Yosys and SymbiYosys | `/opt/yosys` |
| [PYTHON_SETUP.md](PYTHON_SETUP.md) | `uv`, Python, cocotb and `click` | `/usr/local/bin`, `/opt/uv/python` |
| [SAIL_SETUP.md](SAIL_SETUP.md) | The Sail RISC-V model | `/opt/riscv-foundation/sail` |
| [ACT4_SETUP.md](ACT4_SETUP.md) | Ruby, Bundler and the dependencies of ACT4 | `/opt/act-bundle`, `/opt/act-uv-cache`, `/opt/act-cache` |
| [GTKWAVE_SETUP.md](GTKWAVE_SETUP.md) | GTKWave | `/opt/gtkwave` |

## 1. Suggested order

Each tool installs on its own, except that ACT4 needs the three before it. For the tests of the project, in this order:

1. [PYTHON_SETUP.md](PYTHON_SETUP.md), [GHDL_SETUP.md](GHDL_SETUP.md) and [YOSYS_SETUP.md](YOSYS_SETUP.md), the tools of the VHDL tests.
2. [GCC_SETUP.md](GCC_SETUP.md) and [SPIKE_SETUP.md](SPIKE_SETUP.md), for building ELFs (compiling assembly and C) and running them on Spike.
3. [SAIL_SETUP.md](SAIL_SETUP.md) and [ACT4_SETUP.md](ACT4_SETUP.md), for the ACT4 certification.
4. [GTKWAVE_SETUP.md](GTKWAVE_SETUP.md), to open the waveforms.

The Quartus Prime Lite of the board flow is installed apart, in [QUARTUS_INSTALL.md](../QUARTUS_INSTALL.md), and the self-hosted runner that uses these tools is set up in [RUNNER_SETUP.md](../RUNNER_SETUP.md).

## 2. Common to the guides

- Every guide covers Debian-like (`apt`) and RHEL-like (`dnf`/`yum`) distros. The commands were run on Ubuntu 26.04 and on Rocky Linux 9, except the GHDL build on RHEL-like distros, which was run on Fedora because GNAT does not install on Rocky Linux 9.
- The scripts of the GHDL, Yosys, Python, Sail, GTKWave and ACT4 guides run as root. Those that build a tool record the version they installed in a `.tag` file inside its directory, and running one again at that version does nothing.
- The Docker images that hold the same tools are described in the [overview of the images](../docker/README.md).

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).