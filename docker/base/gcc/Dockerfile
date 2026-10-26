# The RISC-V GCC for rv32i, rv32i_zmmul and rv32im with ilp32 and the hard-float variants
# rv32imf/ilp32f and rv32imfd/ilp32d, alone: binutils, the compiler and libgcc, with no C library. base-picolibc is compiled with this compiler and added to the same prefix. See
# docs/en/docker/base-gcc.md.
#
#   docker build -f docker/base/gcc/Dockerfile -t base-gcc \
#     --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG RISCV_GNU_TOOLCHAIN_COMMIT

RUN test -n "${RISCV_GNU_TOOLCHAIN_COMMIT}" \
 || { echo "pass --build-arg RISCV_GNU_TOOLCHAIN_COMMIT=<commit>"; exit 1; }

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      autoconf automake autotools-dev curl python3 \
      libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
      gperf libtool patchutils bc zlib1g-dev libexpat1-dev git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/riscv-collab/riscv-gnu-toolchain "${RISCV_GNU_TOOLCHAIN_COMMIT}" \
 && git -C /src checkout FETCH_HEAD \
 && git -C /src submodule update --init --depth 1 binutils gcc

# binutils from riscv-gnu-toolchain, then the compiler configured here (its picolibc rule disables
# multilib): C and C++ front ends, installed, and libgcc built with it for each variant. The host
# programs are stripped of their symbols, which are most of the size of the install. The
# variants are the soft-float ABI with the integer base, with multiply only and with multiply and
# divide, and the two hard-float ones, rv32im/ilp32 being the default.
ARG MULTILIB="rv32i-ilp32--;rv32i_zmmul-ilp32--;rv32im-ilp32--;rv32imf-ilp32f--;rv32imfd-ilp32d--"
RUN prefix=/opt/riscv-foundation/riscv32-elf \
 && mkdir /build \
 && cd /build \
 && /src/configure --prefix=$prefix --with-arch=rv32im --enable-picolibc \
 && make -j"$(nproc)" stamps/build-binutils-picolibc \
 && mkdir gcc \
 && cd gcc \
 && /src/gcc/configure --target=riscv32-unknown-elf --prefix=$prefix \
      --disable-shared --disable-threads --with-system-zlib --enable-tls --with-newlib --with-picolibc \
      --with-sysroot=$prefix/riscv32-unknown-elf \
      --disable-libmudflap --disable-libssp --disable-libquadmath --disable-libgomp --disable-nls \
      --disable-tm-clone-registry --src=/src/gcc \
      --with-multilib-generator="${MULTILIB}" \
      --with-arch=rv32im --with-abi=ilp32 --with-isa-spec=20191213 --enable-languages=c,c++ \
      CFLAGS_FOR_TARGET="-Os -mcmodel=medlow" CXXFLAGS_FOR_TARGET="-Os -mcmodel=medlow" \
 && make -j"$(nproc)" all-gcc \
 && make install-gcc \
 && make -j"$(nproc)" all-target-libgcc \
 && make install-target-libgcc \
 && echo "${RISCV_GNU_TOOLCHAIN_COMMIT}" > $prefix/.tag \
 && find $prefix/bin $prefix/libexec $prefix/riscv32-unknown-elf/bin -type f -perm /111 \
      -exec sh -c 'for f; do [ "$(head -c 4 "$f" | tail -c 3)" = ELF ] && strip --strip-unneeded "$f"; done; true' sh {} + \
 && rm -rf /build /src

# Fail the build, before anything is published, if the compiler does not run or lacks libgcc for a
# variant.
RUN export PATH="/opt/riscv-foundation/riscv32-elf/bin:${PATH}" \
 && riscv32-unknown-elf-gcc --version \
 && riscv32-unknown-elf-gcc -print-multi-lib \
 && for v in "-march=rv32i -mabi=ilp32" "-march=rv32i_zmmul -mabi=ilp32" "-march=rv32im -mabi=ilp32" "-march=rv32imf -mabi=ilp32f" "-march=rv32imfd -mabi=ilp32d"; do \
      test -s "$(riscv32-unknown-elf-gcc $v -print-libgcc-file-name)" || exit 1; \
    done


FROM scratch
ARG RISCV_GNU_TOOLCHAIN_COMMIT
LABEL riscv-gnu-toolchain.commit="${RISCV_GNU_TOOLCHAIN_COMMIT}"
COPY --from=build /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
