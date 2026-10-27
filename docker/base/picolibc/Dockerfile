# picolibc for the RISC-V GCC of docker/base/gcc/Dockerfile (every variant of that GCC), alone. The
# published image holds just the files picolibc installs into that GCC's sysroot; ci-elf copies
# them over the GCC's prefix. picolibc is compiled with the GCC of base-gcc, so the image carries
# the commit of that GCC. See docs/en/docker/base-picolibc.md.
#
#   docker build -f docker/base/picolibc/Dockerfile -t base-picolibc \
#     --build-arg GCC_IMAGE=base-gcc \
#     --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
#     --build-arg GCC_COMMIT=<the riscv-gnu-toolchain.commit label of base-gcc> .

ARG BASE_IMAGE=ubuntu:26.04
ARG GCC_IMAGE=ghcr.io/insper-riscv/base-gcc:latest

FROM ${GCC_IMAGE} AS gcc

FROM ${BASE_IMAGE} AS build
ARG PICOLIBC_COMMIT

RUN test -n "${PICOLIBC_COMMIT}" \
 || { echo "pass --build-arg PICOLIBC_COMMIT=<commit>"; exit 1; }

# meson and ninja build picolibc, with a host C compiler that meson looks for even in a cross build;
# libmpc3 and libmpfr6 are what cc1 of the RISC-V GCC links against.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git python3 meson ninja-build build-essential libmpc3 libmpfr6 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gcc /opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/picolibc/picolibc "${PICOLIBC_COMMIT}" \
 && git -C /src checkout FETCH_HEAD

# The cross file and the options of riscv-gnu-toolchain's picolibc rule: the code model of the GCC
# (medlow), picolibc's own -msave-restore and -fno-common, minimum size, and a sysroot install
# into riscv32-unknown-elf. DESTDIR keeps the result apart from the GCC's files.
RUN set -e; \
    prefix=/opt/riscv-foundation/riscv32-elf; tuple=riscv32-unknown-elf; tool=$prefix/bin/$tuple; \
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
      echo "cpu_family = 'riscv32'"; \
      echo "cpu = 'riscv32'"; \
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
      -Dtests=false; \
    DESTDIR=/out ninja -C /build/out install; \
    echo "${PICOLIBC_COMMIT}" > /out$prefix/.picolibc.tag

# Fail the build, before anything is published, if the GCC cannot use what was built: for each
# variant a program compiles against it with picolibc.specs and the library reports its version.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    cp -r /out/opt/riscv-foundation/riscv32-elf/. /opt/riscv-foundation/riscv32-elf/; \
    export PATH=/opt/riscv-foundation/riscv32-elf/bin:$PATH; \
    printf '%s\n' '#include <picolibc.h>' '#include <stdio.h>' \
      'int main(void) { printf("%s\n", __PICOLIBC_VERSION__); return 0; }' > t.c; \
    for v in "-march=rv32i -mabi=ilp32" "-march=rv32i_zmmul -mabi=ilp32" "-march=rv32im -mabi=ilp32" "-march=rv32imf -mabi=ilp32f" "-march=rv32imfd -mabi=ilp32d"; do \
      riscv32-unknown-elf-gcc $v --specs=picolibc.specs -T/dev/null -c t.c -o t.o; \
      test -s "$(riscv32-unknown-elf-gcc $v --specs=picolibc.specs -print-file-name=libc.a)"; \
    done; \
    grep -h "__PICOLIBC_VERSION__" /opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf/include/picolibc.h | head -n 1; \
    cd /; rm -rf "$d"


FROM scratch
ARG PICOLIBC_COMMIT
ARG GCC_COMMIT
LABEL picolibc.commit="${PICOLIBC_COMMIT}"
LABEL riscv-gnu-toolchain.commit="${GCC_COMMIT}"
COPY --from=build /out/opt/riscv-foundation/riscv32-elf /opt/riscv-foundation/riscv32-elf
