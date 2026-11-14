# Level 2 of the images: the VHDL image plus the RISC-V GCC, picolibc (with libstdc++) and Spike, for
# linux/amd64 and linux/arm64. The GCC, picolibc and Spike are copied from base-gcc, base-picolibc and
# base-spike, and the 64-bit variants of picolibc from base-picolibc-rv64. See docs/en/docker/ci-elf.md.
#
#   docker buildx build --platform linux/amd64,linux/arm64 -f docker/ci/elf/Dockerfile -t ci-elf \
#     --build-arg VHDL_IMAGE=ci-vhdl --build-arg GCC_IMAGE=base-gcc \
#     --build-arg PICOLIBC_IMAGE=base-picolibc --build-arg PICOLIBC_RV64_IMAGE=base-picolibc-rv64 \
#     --build-arg SPIKE_IMAGE=base-spike .

ARG VHDL_IMAGE=ghcr.io/insper-riscv/ci-vhdl:latest
ARG GCC_IMAGE=ghcr.io/insper-riscv/base-gcc:latest
ARG PICOLIBC_IMAGE=ghcr.io/insper-riscv/base-picolibc:latest
ARG PICOLIBC_RV64_IMAGE=ghcr.io/insper-riscv/base-picolibc-rv64:latest
ARG SPIKE_IMAGE=ghcr.io/insper-riscv/base-spike:latest

FROM ${GCC_IMAGE} AS gcc
FROM ${PICOLIBC_IMAGE} AS picolibc
FROM ${PICOLIBC_RV64_IMAGE} AS picolibc-rv64
FROM ${SPIKE_IMAGE} AS spike

FROM ${VHDL_IMAGE}

# libmpc3 and libmpfr6 are what cc1 of the RISC-V GCC links against; Spike needs nothing beyond the
# base image.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libmpc3 libmpfr6 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gcc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
# The two picolibc images install into the same prefix: their library directories do not overlap, and
# every file they both have (the headers, the specs, the linker scripts, the C++ headers) must be the
# same, or the one copied second would replace the other's.
RUN --mount=type=bind,from=picolibc,source=/opt/riscv-foundation/riscv32-elf,target=/p32 \
    --mount=type=bind,from=picolibc-rv64,source=/opt/riscv-foundation/riscv32-elf,target=/p64 \
    set -e; cd /p64; \
    find . -type f | while read -r f; do \
      if [ -e "/p32/$f" ] && ! cmp -s "$f" "/p32/$f"; then echo "the picolibc images differ in $f"; exit 1; fi; \
    done
COPY --from=picolibc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=picolibc-rv64 /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
COPY --from=spike /opt/riscv-foundation/spike /opt/riscv-foundation/spike

ENV PATH=/opt/riscv-foundation/riscv32-elf/bin:/opt/riscv-foundation/spike/bin:$PATH

# Fail the build here, not in a user's CI: the GCC compiles with picolibc and has libgcc, it has a
# libgcc, a libc and a libstdc++ for every library variant it lists, and Spike runs.
RUN set -e; \
    echo "gcc       $(riscv32-unknown-elf-gcc --version | head -n 1) (riscv-gnu-toolchain $(tail -n 1 /opt/riscv-foundation/riscv32-elf/.tag))"; \
    riscv32-unknown-elf-gcc --specs=picolibc.specs -E -x c /dev/null -o /dev/null; \
    test -s "$(riscv32-unknown-elf-gcc -print-libgcc-file-name)"; \
    echo "picolibc  $(tail -n 1 /opt/riscv-foundation/riscv32-elf/.picolibc.tag)"; \
    echo "picolibc  $(tail -n 1 /opt/riscv-foundation/riscv32-elf/.picolibc-rv64.tag) (64 bits)"; \
    riscv32-unknown-elf-gcc -print-multi-lib | while read -r line; do \
      v="$(printf '%s' "${line#*;}" | sed 's/@/ -/g')"; \
      test -s "$(riscv32-unknown-elf-gcc $v -print-libgcc-file-name)" || exit 1; \
      test -s "$(riscv32-unknown-elf-gcc $v --specs=picolibc.specs -print-file-name=libc.a)" || exit 1; \
      test -s "$(riscv32-unknown-elf-g++ $v --specs=picolibc.specs -print-file-name=libstdc++.a)" || exit 1; \
    done; \
    test -s /opt/riscv-foundation/spike/.tag; \
    echo "spike     $(spike --help 2>&1 | head -n 1) (commit $(tail -n 1 /opt/riscv-foundation/spike/.tag))"

WORKDIR /workspace
