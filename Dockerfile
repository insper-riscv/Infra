# syntax=docker/dockerfile:1
#
# Everything the Insper RISC-V infrastructure needs except Quartus: GHDL, the
# RISC-V GCC with picolibc, Spike and uv, at the paths of the workstation
# install (docs/en/GCC_SETUP.md and docs/en/SPIKE_SETUP.md build the same
# things). The GCC and Spike come from the images Dockerfile.gcc and
# Dockerfile.spike publish, so this build only copies them.
#
#   docker build -t infra-toolchain .
#   docker run --rm -it -v "$PWD:/workspace" infra-toolchain

ARG GHDL_IMAGE=ghdl/ghdl:6.0.0-mcode-ubuntu-24.04
ARG UV_VERSION=0.12.21
ARG GCC_IMAGE=ghcr.io/insper-riscv/infra-gcc:latest
ARG SPIKE_IMAGE=ghcr.io/insper-riscv/infra-spike:latest

FROM ${GCC_IMAGE} AS gcc
FROM ${SPIKE_IMAGE} AS spike
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM ${GHDL_IMAGE}

# libmpc3 and libmpfr6 are what cc1 of the GCC links against; Spike needs
# nothing beyond the base image. git, curl and make are for whoever uses the
# image: the checkout of a workflow, installers and ACT4's own make.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git make \
      libmpc3 libmpfr6 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gcc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=spike /opt/riscv-foundation/spike /opt/riscv-foundation/spike
COPY --from=uv /uv /uvx /usr/local/bin/

ENV PATH=/opt/riscv-foundation/riscv32-elf/bin:/opt/riscv-foundation/spike/bin:$PATH

WORKDIR /workspace
