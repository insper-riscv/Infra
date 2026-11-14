# The RISC-V GCC for every combination of the I and E bases, multiply (none, Zmmul, M), F and D with
# the ABIs each allows, and without or with A, C and B, for RV32 and for RV64 (384 variants, 192 of each
# width, D only with the I base), alone:
# binutils, the compiler and libgcc, with no C library. base-picolibc is compiled with this compiler
# and added to the same prefix. See docs/en/docker/base-gcc.md.
#
#   docker build -f docker/base/gcc/Dockerfile -t base-gcc \
#     --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG RISCV_GNU_TOOLCHAIN_COMMIT
# The release the commit belongs to (a release named for its date, 2026.10.29, gives the date of the .tag line 2).
ARG RISCV_GNU_TOOLCHAIN_RELEASE=
# The GCC version the commit bundles (with -dev when its gcc is not a release): the first word of the .tag line 2.
# Empty in a local build, which then reads the BASE-VER of the gcc it builds.
ARG RISCV_GNU_TOOLCHAIN_GCC_VERSION=

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
# variants are listed by scripts/gcc-multilib.sh, rv32i/ilp32 being the default (medlow code model;
# the RV64 variants, lp64*, get medany, the model they need above 2 GiB); the build argument
# MULTILIB replaces that list, in the format of --with-multilib-generator.
COPY scripts/gcc-multilib.sh /usr/local/bin/gcc-multilib.sh
ARG MULTILIB=""
RUN multilib="${MULTILIB:-$(bash /usr/local/bin/gcc-multilib.sh)}" \
 && prefix=/opt/riscv-foundation/riscv32-elf \
 && mkdir /build \
 && cd /build \
 && /src/configure --prefix=$prefix --with-arch=rv32i --with-abi=ilp32 --enable-picolibc \
 && make -j"$(nproc)" stamps/build-binutils-picolibc \
 && mkdir gcc \
 && cd gcc \
 && /src/gcc/configure --target=riscv32-unknown-elf --prefix=$prefix \
      --disable-shared --disable-threads --with-system-zlib --enable-tls --with-newlib --with-picolibc \
      --with-sysroot=$prefix/riscv32-unknown-elf \
      --disable-libmudflap --disable-libssp --disable-libquadmath --disable-libgomp --disable-nls \
      --disable-tm-clone-registry --src=/src/gcc \
      --with-multilib-generator="${multilib}" \
      --with-arch=rv32i --with-abi=ilp32 --with-isa-spec=20191213 --enable-languages=c,c++ \
      --with-specs='%{mabi=lp64*:%{!mcmodel=*:-mcmodel=medany}}' \
      CFLAGS_FOR_TARGET="-Os" CXXFLAGS_FOR_TARGET="-Os" \
 && make -j"$(nproc)" all-gcc \
 && make install-gcc \
 && make -j"$(nproc)" all-target-libgcc \
 && make install-target-libgcc \
 && { echo "${RISCV_GNU_TOOLCHAIN_COMMIT}"; echo "${RISCV_GNU_TOOLCHAIN_GCC_VERSION:-$(cat /src/gcc/gcc/BASE-VER)} $(case "${RISCV_GNU_TOOLCHAIN_RELEASE}" in [0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]) echo "${RISCV_GNU_TOOLCHAIN_RELEASE}" | tr . - ;; *) git -C /src log -1 --format=%cs ;; esac) ($(echo "${RISCV_GNU_TOOLCHAIN_COMMIT}" | cut -c1-7)), $(echo "${multilib}" | tr ';' '\n' | wc -l) variants"; } > $prefix/.tag \
 && find $prefix/bin $prefix/libexec $prefix/riscv32-unknown-elf/bin -type f -perm /111 \
      -exec sh -c 'for f; do [ "$(head -c 4 "$f" | tail -c 3)" = ELF ] && strip --strip-unneeded "$f"; done; true' sh {} + \
 && rm -rf /build /src

# Fail the build, before anything is published, if the compiler does not run, does not default to
# rv32i with ilp32 (the root of the library directory), or lacks libgcc for a variant.
RUN export PATH="/opt/riscv-foundation/riscv32-elf/bin:${PATH}" \
 && riscv32-unknown-elf-gcc --version \
 && riscv32-unknown-elf-gcc -print-multi-lib \
 && test "$(riscv32-unknown-elf-gcc -print-multi-directory)" = "." \
 && test "$(riscv32-unknown-elf-gcc -print-multi-lib | head -n 1)" = ".;" \
 && test "$(riscv32-unknown-elf-gcc -print-multi-lib | wc -l)" = "$(tail -n 1 /opt/riscv-foundation/riscv32-elf/.tag | sed 's/.*, \([0-9][0-9]*\) variants$/\1/')" \
 && riscv32-unknown-elf-gcc -print-multi-lib | while read -r line; do \
      v="$(printf '%s' "${line#*;}" | sed 's/@/ -/g')"; \
      test -s "$(riscv32-unknown-elf-gcc $v -print-libgcc-file-name)" || exit 1; \
    done


FROM scratch
ARG RISCV_GNU_TOOLCHAIN_COMMIT
LABEL riscv-gnu-toolchain.commit="${RISCV_GNU_TOOLCHAIN_COMMIT}"
COPY --from=build /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
