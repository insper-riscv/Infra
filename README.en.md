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
[TOOLCHAIN_IMAGE.md](docs/en/TOOLCHAIN_IMAGE.md) and [DEVTOOLS_IMAGE.md](docs/en/DEVTOOLS_IMAGE.md), and why each version was chosen is in
[section 8 of TOOLCHAIN_IMAGE.md](docs/en/TOOLCHAIN_IMAGE.md#8-why-each-version).

### Toolchain image (`ghcr.io/insper-riscv/infra-toolchain`)

| Item | Version | Why it is in the image |
| :--- | :--- | :--- |
| Ubuntu | 26.04 LTS | base of every image: the latest long-term release, with `amd64` and `arm64` builds, and the one GHDL 6.0.0 was built and tested on |
| GHDL (LLVM backend) | 6.0.0 | simulates the VHDL-2008 of the core; the LLVM backend because the `mcode` one runs only on x86, and a simulation must behave the same on a PC and on an ARM machine |
| LLVM (`libllvm21`, library the GHDL backend runs on) | 21.1.8 | the code generator GHDL links against |
| RISC-V GCC (`rv32im`, `ilp32`: no CSR, no F or D) | 16.1.0 (`riscv-gnu-toolchain` commit `d118e53`) | compiles the test programs for the core |
| picolibc (C library of the RISC-V GCC, one variant for the same `rv32im`: no CSR, floating point in software) | 1.8.11 | the C library those programs link against |
| Spike | 1.1.1-dev (`riscv-isa-sim` commit `fdc1ffa`, debug module at `0x70000000`) | the reference simulator that produces the golden result of each program; its debug module is moved so that it does not overlap the boot ROM |
| `uv` | 0.13.0 | installs Python and the dependencies of each project (`uv sync`); the image has no `pip` |
| Python | 3.14.8 | the version the projects require (`>=3.14,<3.15`) |
| cocotb | 2.1.0 | the testbenches, written in Python; it is what fixes the Python version |
| `gcc` and `g++` (host) | 15.2.0 | `gcc` links the executable GHDL elaborates; `g++` compiles cocotb on `arm64`, where it has no wheel |
| `libc6-dev` | 2.43 | the C headers and libraries `gcc` needs to link that executable and to build VHPIDIRECT code |
| `zlib1g-dev` | 1.3.1 | the executable GHDL elaborates is linked with `-lz` |
| `libgnat-14` | 14.3.0 | the Ada runtime GHDL, written in Ada, runs on |
| `libedit2` | 3.1 | the line-editing library GHDL links against |
| `libmpc3` and `libmpfr6` | 1.3.1 and 4.2.2 | the arithmetic libraries the compiler proper (`cc1`) of the RISC-V GCC links against |
| `git` | 2.53.0 | the checkout of a workflow and the clones of the sibling repositories |
| `make` | 4.4.1 | the Makefiles of the projects and ACT4's own `make` |
| `curl` | 8.18.0 | installers and downloads |
| `ca-certificates` | 20260601 | the trusted certificates, so that `curl` and `git` verify HTTPS servers |
| `libglib2.0-0t64` | 2.88.0 | `libglib-2.0` and `libgthread-2.0`, which the command-line tools of a Quartus installation mounted from the host link against |
| Yosys | 0.52 | reads the Verilog netlist GHDL synthesizes from the VHDL, for formal verification |
| SymbiYosys (`sby`) | v0.69 | runs Yosys and the solvers to prove properties of a block |
| `z3` and `boolector` | 4.13.3 and 1.5.118 | the SMT solvers SymbiYosys uses |
| `click` | 8.5.0 | the Python library `sby` imports |

### Dev tools image (`ghcr.io/insper-riscv/dev_tools`)

Everything in the toolchain image, plus:

| Item | Version | Why it is in the image |
| :--- | :--- | :--- |
| GTKWave (GTK 3 tree, Wayland and X11) | 3.3.116 | opens the waveforms (`.ghw`, `.fst`) of a simulation |
| GTK 3 (`libgtk-3-0t64`) | 3.24.52 | the toolkit GTKWave runs on, with its Wayland and X11 backends |
| `libjudydebian1`, `libbz2-1.0` and `liblzma5` | 1.0.5, 1.0.8 and 5.8.3 | libraries GTKWave links against (Judy arrays, bzip2 and xz) |
| `adwaita-icon-theme` and `shared-mime-info` | 50.0 and 2.4 | the icons and the MIME database GTK reads |
| `build-essential` and `pkg-config` | 12.12 and 2.5.1 | compile the C of the projects that have it and find the flags of a library |
| `gnat` | 14 | the Ada compiler and runtime for building GHDL or Ada code in the development environment |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
