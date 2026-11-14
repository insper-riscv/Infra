# picolibc and the C++ libraries (libsupc++ and libstdc++) for the RISC-V GCC of
# docker/base/gcc/Dockerfile, for the library variants of one width (WIDTH 32 or 64), alone. The
# published image holds just the files picolibc and libstdc++ install into that GCC's sysroot; ci-elf
# copies the images of both widths over the GCC's prefix. They are compiled with the GCC of base-gcc,
# so the image carries the commit of that GCC. See docs/en/docker/base-picolibc.md.
#
#   docker build -f docker/base/picolibc/Dockerfile -t base-picolibc \
#     --build-arg GCC_IMAGE=base-gcc --build-arg WIDTH=32 \
#     --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
#     --build-arg GCC_COMMIT=<the riscv-gnu-toolchain.commit label of base-gcc> .
#
# WIDTH=64 builds base-picolibc-rv64 from the same recipe.

ARG BASE_IMAGE=ubuntu:26.04
ARG GCC_IMAGE=ghcr.io/insper-riscv/base-gcc:latest

FROM ${GCC_IMAGE} AS gcc

FROM ${BASE_IMAGE} AS build
ARG PICOLIBC_COMMIT
# The riscv-gnu-toolchain commit of the GCC: its gcc source builds the C++ libraries.
ARG GCC_COMMIT
# 32 or 64: which variants of the GCC this image builds (rv32 and the root of the library directory,
# or rv64).
ARG WIDTH=32
# How many variants of libstdc++ are built before the build tree is deleted (about 0.65 GB each).
ARG CXX_BATCH=12

RUN test -n "${PICOLIBC_COMMIT}" \
 || { echo "pass --build-arg PICOLIBC_COMMIT=<commit>"; exit 1; }
RUN test -n "${GCC_COMMIT}" \
 || { echo "pass --build-arg GCC_COMMIT=<commit>"; exit 1; }
RUN case "${WIDTH}" in 32|64) ;; *) echo "WIDTH must be 32 or 64"; exit 1 ;; esac

# meson and ninja build picolibc, with a host C compiler that meson looks for even in a cross build;
# libmpc3 and libmpfr6 are what cc1 of the RISC-V GCC links against; the rest is what configuring
# the target libraries of the GCC source asks of the host.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git python3 meson ninja-build build-essential libmpc-dev libmpfr-dev libgmp-dev \
      zlib1g-dev gawk bison flex texinfo \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gcc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/picolibc/picolibc "${PICOLIBC_COMMIT}" \
 && git -C /src checkout FETCH_HEAD

# The cross file and the options of riscv-gnu-toolchain's picolibc rule: the code model of the GCC
# (medlow), picolibc's own -msave-restore and -fno-common, minimum size, and a sysroot install
# into riscv32-unknown-elf. DESTDIR keeps the result apart from the GCC's files. picolibc has no
# option that selects a width, so multilib-list names the variants of the GCC that belong to it: the
# root and rv32 for width 32, rv64 for width 64. The headers are installed once, by the first
# variant it builds.
RUN set -e; \
    prefix=/opt/riscv-foundation/riscv32-elf; tuple=riscv32-unknown-elf; tool=$prefix/bin/$tuple; \
    if [ "${WIDTH}" = 32 ]; then pick='^(\.|rv32)'; else pick='^rv64'; fi; \
    list="$($tool-gcc -print-multi-lib | cut -d';' -f1 | grep -E "$pick" | paste -sd,)"; \
    test -n "$list"; \
    mkdir /build; \
    { \
      echo "[binaries]"; \
      echo "c = ['$tool-gcc', '-nostdlib']"; \
      echo "cpp = ['$tool-g++', '-nostdlib']"; \
      echo "ar = '$tool-ar'"; \
      echo "as = '$tool-as'"; \
      echo "nm = '$tool-nm'"; \
      echo "strip = '$tool-strip'"; \
      echo "[host_machine]"; \
      echo "system = 'unknown'"; \
      echo "cpu_family = 'riscv${WIDTH}'"; \
      echo "cpu = 'riscv${WIDTH}'"; \
      echo "endian = 'little'"; \
      echo "[properties]"; \
      echo "c_args = ['-msave-restore', '-fno-common', '-mcmodel=medlow']"; \
      echo "cpp_args = ['-msave-restore', '-fno-common', '-mcmodel=medlow']"; \
      echo "skip_sanity_check = true"; \
    } > /build/cross.txt; \
    meson setup /build/out /src \
      --cross-file /build/cross.txt \
      --buildtype=minsize \
      --prefix=$prefix/$tuple \
      -Dincludedir=include \
      -Dlibdir=lib \
      -Dsysroot-install=true \
      -Dsystem-libc=true \
      -Dtests=false \
      "-Dmultilib-list=$list"; \
    DESTDIR=/out ninja -C /build/out install; \
    echo "${PICOLIBC_COMMIT}" > /out$prefix/.picolibc.tag

# Fail the build, before anything is published, if the GCC cannot use what was built: for each
# variant of the width a program compiles against it with picolibc.specs and has libc.a. The result
# is copied into the GCC's prefix, where the C++ libraries are built against it.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    cp -r /out/opt/riscv-foundation/riscv32-elf/. /opt/riscv-foundation/riscv32-elf/; \
    export PATH=/opt/riscv-foundation/riscv32-elf/bin:$PATH; \
    if [ "${WIDTH}" = 32 ]; then pick='^(\.|rv32)'; else pick='^rv64'; fi; \
    printf '%s\n' '#include <picolibc.h>' '#include <stdio.h>' \
      'int main(void) { printf("%s\n", __PICOLIBC_VERSION__); return 0; }' > t.c; \
    riscv32-unknown-elf-gcc -print-multi-lib | grep -E "$pick" | while read -r line; do \
      v="$(printf '%s' "${line#*;}" | sed 's/@/ -/g')"; \
      riscv32-unknown-elf-gcc $v --specs=picolibc.specs -T/dev/null -c t.c -o t.o; \
      test -s "$(riscv32-unknown-elf-gcc $v --specs=picolibc.specs -print-file-name=libc.a)" || exit 1; \
    done; \
    grep -h "__PICOLIBC_VERSION__" /opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf/include/picolibc.h | head -n 1; \
    cd /; rm -rf "$d"

# The C++ libraries: the gcc source of the commit of the GCC (a shallow clone of just that submodule),
# which must be the version of the installed compiler, then libsupc++ and libstdc++ for each variant
# of the width, in batches (scripts/cxx-libs.sh). The headers go to the sysroot, and a variant
# without the library does not compile C++.
COPY scripts/cxx-libs.sh /usr/local/bin/cxx-libs.sh
RUN set -e; \
    git init /gcc-src; \
    git -C /gcc-src fetch --depth 1 https://github.com/riscv-collab/riscv-gnu-toolchain "${GCC_COMMIT}"; \
    git -C /gcc-src checkout FETCH_HEAD; \
    git -C /gcc-src submodule update --init --depth 1 gcc; \
    export PATH=/opt/riscv-foundation/riscv32-elf/bin:$PATH; \
    test "$(cat /gcc-src/gcc/gcc/BASE-VER)" = "$(riscv32-unknown-elf-gcc -dumpfullversion)"; \
    bash /usr/local/bin/cxx-libs.sh "${WIDTH}" /gcc-src/gcc /opt/riscv-foundation/riscv32-elf /out "${CXX_BATCH}"; \
    rm -rf /gcc-src

# Fail the build if a variant of the width lacks libstdc++, libsupc++ or a C++ header set, or if a
# C++ program with a container, an exception and a global constructor does not compile for it; then
# write the tag, with the picolibc version and the number of variants.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    cp -r /out/opt/riscv-foundation/riscv32-elf/. /opt/riscv-foundation/riscv32-elf/; \
    export PATH=/opt/riscv-foundation/riscv32-elf/bin:$PATH; \
    if [ "${WIDTH}" = 32 ]; then pick='^(\.|rv32)'; tag=.picolibc.tag; else pick='^rv64'; tag=.picolibc-rv64.tag; fi; \
    printf '%s\n' '#include <vector>' '#include <string>' '#include <new>' \
      'struct G { G() { v.push_back(1); } std::vector<int> v; } g;' \
      'int f(int x) { try { if (x) throw x; } catch (int e) { return e; } return new int(x) != nullptr; }' > t.cc; \
    riscv32-unknown-elf-gcc -print-multi-lib | grep -E "$pick" | while read -r line; do \
      v="$(printf '%s' "${line#*;}" | sed 's/@/ -/g')"; \
      riscv32-unknown-elf-g++ $v --specs=picolibc.specs -c t.cc -o t.o; \
      for lib in libstdc++.a libsupc++.a; do \
        test -s "$(riscv32-unknown-elf-g++ $v --specs=picolibc.specs -print-file-name=$lib)" || exit 1; \
      done; \
    done; \
    ver="$(sed -n 's/.*__PICOLIBC_VERSION__ "\(.*\)".*/\1/p' /opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf/include/picolibc.h | head -n 1)"; \
    n="$(riscv32-unknown-elf-gcc -print-multi-lib | grep -cE "$pick")"; \
    printf '%s %s (%.7s), %s variants, libstdc++ %s\n' "$ver" "$(git -C /src log -1 --format=%cs)" "${PICOLIBC_COMMIT}" "$n" \
      "$(riscv32-unknown-elf-gcc -dumpfullversion)" >> /out/opt/riscv-foundation/riscv32-elf/.picolibc.tag; \
    if [ "$tag" != .picolibc.tag ]; then mv /out/opt/riscv-foundation/riscv32-elf/.picolibc.tag /out/opt/riscv-foundation/riscv32-elf/$tag; fi; \
    cd /; rm -rf "$d"


FROM scratch
ARG PICOLIBC_COMMIT
ARG GCC_COMMIT
LABEL picolibc.commit="${PICOLIBC_COMMIT}"
LABEL riscv-gnu-toolchain.commit="${GCC_COMMIT}"
COPY --from=build /out/opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
