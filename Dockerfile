# syntax=docker/dockerfile:1
#
# Everything the Insper RISC-V infrastructure needs except Quartus: GHDL, the RISC-V GCC with
# picolibc, Spike, uv, and the formal tools (Yosys, SymbiYosys and the z3 and boolector solvers;
# GHDL turns VHDL into the Verilog netlist Yosys reads). The same image for linux/amd64 and
# linux/arm64: GHDL has the LLVM backend on both (the mcode backend is x86 only), so a simulation
# behaves the same on a PC and on an ARM machine. The GHDL, the GCC, picolibc, Spike, and Yosys with
# SymbiYosys come from the images Dockerfile.ghdl, Dockerfile.gcc, Dockerfile.picolibc,
# Dockerfile.spike and Dockerfile.yosys publish, so this build only copies them; they must be multi-architecture images.
#
# GHDL with the LLVM backend elaborates to an executable: scripts use `ghdl -a`, `ghdl -e` and
# `ghdl -r` (or `ghdl --elab-run`), never a bare `ghdl -r` after only `-a`.
#
#   docker buildx build --platform linux/amd64,linux/arm64 -t infra-toolchain .
#   docker run --rm -it -v "$PWD:/workspace" infra-toolchain

ARG BASE_IMAGE=ubuntu:26.04
ARG UV_VERSION=0.13.0
# Python 3.14 is the version the projects require (>=3.14,<3.15), and cocotb 2.1.0 is the first
# release that supports it: cocotb is what fixes the Python version, so a newer Python waits for a
# cocotb that supports it. Every project simulates with cocotb, so both are in the image; the
# other Python libraries are each project's own and come from its `uv sync`.
ARG PYTHON_VERSION=3.14
ARG COCOTB_VERSION=2.1.0
# click is the Python library SymbiYosys (sby) imports; the image has no pip, so uv installs it.
ARG CLICK_VERSION=8.5.0
ARG GHDL_IMAGE=ghcr.io/insper-riscv/infra-ghdl:latest
ARG GCC_IMAGE=ghcr.io/insper-riscv/infra-gcc:latest
ARG SPIKE_IMAGE=ghcr.io/insper-riscv/infra-spike:latest
ARG PICOLIBC_IMAGE=ghcr.io/insper-riscv/infra-picolibc:latest
ARG YOSYS_IMAGE=ghcr.io/insper-riscv/infra-yosys:latest

FROM ${GHDL_IMAGE} AS ghdl
FROM ${GCC_IMAGE} AS gcc
FROM ${PICOLIBC_IMAGE} AS picolibc
FROM ${SPIKE_IMAGE} AS spike
FROM ${YOSYS_IMAGE} AS yosys
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM ${BASE_IMAGE}

# libgnat, libllvm, zlib and libedit are what GHDL links against (zlib1g-dev, not just the
# library: the executable GHDL elaborates is linked with -lz); gcc and libc6-dev link that
# executable (and build VHPIDIRECT code); g++ is for cocotb, which has no wheel for Linux on arm64
# (only x86-64, macOS and Windows) and is compiled there, here and in every project's `uv sync`;
# libmpc3 and libmpfr6 are what cc1 of the RISC-V GCC links against; Spike needs nothing beyond the
# base image. git, curl and make are for whoever uses the image: the checkout of a workflow,
# installers and ACT4's own make. libglib2.0-0t64 (libglib-2.0 and libgthread-2.0) is the one system
# library the command-line tools of a Quartus installation mounted from the host (quartus_sh,
# quartus_stp, quartus_cdb and the rest) link against and Ubuntu's base image does not have; Quartus
# itself is not in the image. z3 and boolector are the SMT solvers SymbiYosys runs; libreadline8t64,
# libtcl8.6 and libffi8 are what Yosys links against.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git make gcc g++ libc6-dev \
      libgnat-14 libllvm21 zlib1g-dev libedit2 \
      libmpc3 libmpfr6 \
      libglib2.0-0t64 \
      z3 boolector libreadline8t64 libtcl8.6 libffi8 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghdl /opt/ghdl /opt/ghdl
COPY --from=gcc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
# picolibc comes from its own image, compiled with that GCC: its files go over the ones the GCC image
# carries, so a newer picolibc needs no new GCC build.
COPY --from=picolibc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=spike /opt/riscv-foundation/spike /opt/riscv-foundation/spike
COPY --from=yosys /opt/yosys /opt/yosys
COPY --from=uv /uv /uvx /usr/local/bin/

ENV PATH=/opt/ghdl/bin:/opt/riscv-foundation/riscv32-elf/bin:/opt/riscv-foundation/spike/bin:/opt/yosys/bin:$PATH

# Python from uv, in a directory every user reads (a project's `uv sync` finds it there instead of
# downloading it), with cocotb and click (for sby) installed in it, and python3 on the PATH. uv marks the Python it
# installs as externally managed; this one belongs to the image and nothing else manages it, so
# the install says so explicitly.
ARG PYTHON_VERSION
ARG COCOTB_VERSION
ARG CLICK_VERSION
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_PYTHON_PREFERENCE=only-managed
RUN uv python install "${PYTHON_VERSION}" \
 && python="$(uv python find "${PYTHON_VERSION}")" \
 && uv pip install --break-system-packages --python "$python" "cocotb==${COCOTB_VERSION}" "click==${CLICK_VERSION}" \
 && ln -s "$python" /usr/local/bin/python3 \
 && ln -s "$python" /usr/local/bin/python \
 && chmod -R a+rX /opt/uv

# A broken build fails here and not in a user's CI: GHDL runs a VHDL-2008 design, the RISC-V GCC
# compiles with picolibc, Spike runs, and the host gcc, which links the elaborated design, is not
# the RISC-V one; Yosys and sby prove a small property with the z3 solver.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    printf '%s\n' \
      'library ieee; use ieee.std_logic_1164.all;' \
      'entity t is end;' \
      'architecture a of t is signal s : std_logic := '"'"'1'"'"'; begin' \
      '  process begin assert s = '"'"'1'"'"' severity failure; report "ghdl ok"; wait; end process;' \
      'end;' > t.vhd; \
    ghdl --version | head -n 1; \
    ghdl -a --std=08 t.vhd; \
    ghdl --elab-run --std=08 t; \
    riscv32-unknown-elf-gcc --version | head -n 1; \
    riscv32-unknown-elf-gcc --specs=picolibc.specs -E -x c /dev/null -o /dev/null; \
    grep -h '__PICOLIBC_VERSION__' /opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf/include/picolibc.h | head -n 1; \
    test "$(riscv32-unknown-elf-gcc -print-multi-lib)" = ".;"; \
    spike --help 2>&1 | head -n 1 || true; \
    gcc --version | head -n 1; \
    uv --version; \
    python3 -c "import sys, cocotb; assert sys.version_info[:2] == (3, 14); print('python', sys.version.split()[0], 'cocotb', cocotb.__version__)"; \
    yosys -V; \
    printf '%s\n' \
      'module t (input clk);' \
      '  reg [1:0] c = 0;' \
      '  always @(posedge clk) c <= c + 1;' \
      '  always @* assert(c <= 3);' \
      'endmodule' > f.sv; \
    printf '%s\n' '[options]' 'mode prove' 'depth 5' '[engines]' 'smtbmc z3' \
      '[script]' 'read_verilog -formal -sv f.sv' 'prep -top t' '[files]' 'f.sv' > f.sby; \
    sby -f f.sby > sby.log 2>&1 || { cat sby.log; exit 1; }; \
    tail -n 1 sby.log; \
    cd /; rm -rf "$d"

WORKDIR /workspace
