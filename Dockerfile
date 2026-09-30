# syntax=docker/dockerfile:1
#
# Everything the Insper RISC-V infrastructure needs except Quartus: GHDL, the RISC-V GCC
# with picolibc, Spike and uv, at the paths of the workstation install
# (docs/en/GCC_SETUP.md and docs/en/SPIKE_SETUP.md build the same things).
#
#   docker build -t infra-toolchain .
#   docker run --rm -it -v "$PWD:/workspace" infra-toolchain

ARG GHDL_IMAGE=ghdl/ghdl:6.0.0-mcode-ubuntu-24.04
ARG UV_VERSION=0.12.21


# GCC for rv32im/ilp32 with picolibc (GCC_SETUP.md, sections 1 to 3).
FROM ${GHDL_IMAGE} AS gcc-build
ARG RISCV_GNU_TOOLCHAIN_COMMIT=d118e5335a33d4dc77fdc64e5a5223931ab422a0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      autoconf automake autotools-dev curl python3 \
      libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
      gperf libtool patchutils bc zlib1g-dev libexpat1-dev meson ninja-build git \
      cmake libglib2.0-dev expect device-tree-compiler libslirp-dev libzstd-dev \
      libncurses-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/riscv-collab/riscv-gnu-toolchain "${RISCV_GNU_TOOLCHAIN_COMMIT}" \
 && git -C /src checkout FETCH_HEAD \
 && git -C /src submodule update --init --depth 1 binutils gcc gdb picolibc

RUN mkdir /build \
 && cd /build \
 && /src/configure --prefix=/opt/riscv-foundation/riscv32-elf --with-arch=rv32im --enable-picolibc \
 && make -j"$(nproc)" \
 && echo "${RISCV_GNU_TOOLCHAIN_COMMIT}" > /opt/riscv-foundation/riscv32-elf/.tag


# Spike with its debug module moved out of address 0 (SPIKE_SETUP.md, sections 1 to 3).
FROM ${GHDL_IMAGE} AS spike-build
ARG RISCV_ISA_SIM_COMMIT=0bff12123b1fd510e19e19634dd997dbade70e54

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential git ca-certificates device-tree-compiler \
      libboost-regex-dev libboost-system-dev \
 && rm -rf /var/lib/apt/lists/*

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/riscv-software-src/riscv-isa-sim "${RISCV_ISA_SIM_COMMIT}" \
 && git -C /src checkout FETCH_HEAD \
 && sed -i "s/^#define DEBUG_START .*/#define DEBUG_START        0x70000000/" /src/riscv/platform.h

RUN mkdir /build \
 && cd /build \
 && /src/configure --prefix=/opt/riscv-foundation/spike \
 && make -j"$(nproc)" \
 && make install \
 && echo "${RISCV_ISA_SIM_COMMIT}-debug-start" > /opt/riscv-foundation/spike/.tag


FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv


FROM ${GHDL_IMAGE}

# libmpc3 and libmpfr6 are what cc1 of the GCC links against, and the boost
# libraries are Spike's runtime.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git make \
      libmpc3 libmpfr6 libboost-regex1.83.0 libboost-system1.83.0 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gcc-build /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=spike-build /opt/riscv-foundation/spike /opt/riscv-foundation/spike
COPY --from=uv /uv /uvx /usr/local/bin/

ENV PATH=/opt/riscv-foundation/riscv32-elf/bin:/opt/riscv-foundation/spike/bin:$PATH

WORKDIR /workspace
