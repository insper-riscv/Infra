# Level 2 of the images: the VHDL image plus the RISC-V GCC, picolibc and Spike, for linux/amd64
# and linux/arm64. The GCC, picolibc and Spike are copied from base-gcc, base-picolibc and
# base-spike. See docs/en/docker/ci-elf.md.
#
#   docker buildx build --platform linux/amd64,linux/arm64 -f docker/ci/elf/Dockerfile -t ci-elf \
#     --build-arg VHDL_IMAGE=ci-vhdl --build-arg GCC_IMAGE=base-gcc \
#     --build-arg PICOLIBC_IMAGE=base-picolibc --build-arg SPIKE_IMAGE=base-spike .

ARG VHDL_IMAGE=ghcr.io/insper-riscv/ci-vhdl:latest
ARG GCC_IMAGE=ghcr.io/insper-riscv/base-gcc:latest
ARG PICOLIBC_IMAGE=ghcr.io/insper-riscv/base-picolibc:latest
ARG SPIKE_IMAGE=ghcr.io/insper-riscv/base-spike:latest

FROM ${GCC_IMAGE} AS gcc
FROM ${PICOLIBC_IMAGE} AS picolibc
FROM ${SPIKE_IMAGE} AS spike

FROM ${VHDL_IMAGE}

# libmpc3 and libmpfr6 are what cc1 of the RISC-V GCC links against; Spike needs nothing beyond the
# base image.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libmpc3 libmpfr6 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gcc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=picolibc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=spike /opt/riscv-foundation/spike /opt/riscv-foundation/spike

ENV PATH=/opt/riscv-foundation/riscv32-elf/bin:/opt/riscv-foundation/spike/bin:$PATH

# Fail the build here, not in a user's CI: the GCC compiles with picolibc and has libgcc, it has the
# five library variants, and Spike runs.
RUN set -e; \
    echo "gcc       $(riscv32-unknown-elf-gcc --version | head -n 1) (riscv-gnu-toolchain $(cat /opt/riscv-foundation/riscv32-elf/.tag))"; \
    riscv32-unknown-elf-gcc --specs=picolibc.specs -E -x c /dev/null -o /dev/null; \
    test -s "$(riscv32-unknown-elf-gcc -print-libgcc-file-name)"; \
    echo "picolibc  $(sed -n 's/.*__PICOLIBC_VERSION__ "\(.*\)"/\1/p' /opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf/include/picolibc.h) (commit $(cat /opt/riscv-foundation/riscv32-elf/.picolibc.tag))"; \
    test "$(riscv32-unknown-elf-gcc -print-multi-lib | wc -l)" = 5; \
    test -s /opt/riscv-foundation/spike/.tag; \
    echo "spike     $(spike --help 2>&1 | head -n 1) (commit $(sed 's/-debug-start$//' /opt/riscv-foundation/spike/.tag))"

WORKDIR /workspace
