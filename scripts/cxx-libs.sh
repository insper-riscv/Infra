#!/usr/bin/env bash
# Builds libsupc++ and libstdc++ of the RISC-V GCC for the library variants of one width, against the
# picolibc already installed in the prefix of that GCC, and installs them under DESTDIR. It is the C++
# stage of docker/base/picolibc/Dockerfile.
#
# The GCC of base-gcc is installed without its source or build tree, so the target libraries are
# configured from the gcc source of the same riscv-gnu-toolchain commit, with the installed compiler
# standing in for the one that would have been built. The variants are built in batches: each batch
# is configured, built, installed and its build tree deleted, so the disk holds one batch at a time.
# libatomic is not built, because GCC does not support it for a bare-metal ELF target.
#
#   scripts/cxx-libs.sh <width> <gcc-source> <prefix> <destdir> <batch-size>
#
#   width        32 or 64: which variants of the compiler to build (for 32, the root of the library
#                directory and every rv32 variant; for 64, every rv64 variant)
#   gcc-source   the gcc directory of riscv-gnu-toolchain
#   prefix       where the GCC and picolibc are installed (/opt/riscv-foundation/riscv32-elf)
#   destdir      the root the libraries and headers are installed under
#   batch-size   how many variants are built before the build tree is deleted
set -euo pipefail

[ "$#" -eq 5 ] || { echo "usage: $0 <width> <gcc-source> <prefix> <destdir> <batch-size>" >&2; exit 2; }
width="$1"; src="$2"; prefix="$3"; dest="$4"; batch="$5"
tuple=riscv32-unknown-elf
tool="$prefix/bin/$tuple"

case "$width" in
  32) pick='^(\.|rv32)' ; cmodel=medlow ;;
  64) pick='^rv64' ; cmodel=medany ;;
  *) echo "width must be 32 or 64" >&2; exit 2 ;;
esac

work="$(mktemp -d /tmp/cxx-libs.XXXXXX)"
trap 'rm -rf "$work"' EXIT

# The configure and the build ask the compiler for its variants (-print-multi-lib). These wrappers
# answer with only the lines of the batch being built, which is how a batch is chosen.
mkdir "$work/wrap"
for lang in gcc g++; do
  cat > "$work/wrap/wrap-$lang" <<WRAP
#!/bin/bash
for arg in "\$@"; do
  case "\$arg" in
    -print-multi-lib|--print-multi-lib) $tool-$lang "\$@" | grep -Fx -f "\$CXX_BATCH_LINES"; exit ;;
  esac
done
exec $tool-$lang "\$@"
WRAP
  chmod +x "$work/wrap/wrap-$lang"
done

"$tool-gcc" -print-multi-lib | grep -E "$pick" > "$work/all.txt"
total="$(wc -l < "$work/all.txt")"
split -l "$batch" -d "$work/all.txt" "$work/batch."
echo "libstdc++ for $total variants of width $width, in batches of $batch"

cc="$work/wrap/wrap-gcc"
cxx="$work/wrap/wrap-g++"
for lines in "$work"/batch.*; do
  n="$(wc -l < "$lines")"
  start="$(date +%s)"
  export CXX_BATCH_LINES="$lines"
  rm -rf "$work/build"
  mkdir "$work/build"
  cd "$work/build"
  {
    "$src/configure" --target="$tuple" --prefix="$prefix" \
      --disable-shared --disable-threads --with-system-zlib --enable-tls --with-newlib --with-picolibc \
      --with-sysroot="$prefix/$tuple" \
      --disable-libmudflap --disable-libssp --disable-libquadmath --disable-libgomp --disable-nls \
      --disable-tm-clone-registry \
      --with-arch=rv32i --with-abi=ilp32 --with-isa-spec=20191213 --enable-languages=c,c++ \
      --with-build-time-tools="$prefix/$tuple/bin" \
      CC_FOR_TARGET="$cc" CXX_FOR_TARGET="$cxx" \
      CFLAGS_FOR_TARGET="-Os -mcmodel=$cmodel" CXXFLAGS_FOR_TARGET="-Os -mcmodel=$cmodel"
    # The compiler targets are marked as up to date (-o), so make does not build the GCC, and the
    # compilers are given on the command line because the configure values do not reach the rules.
    make -j"$(nproc)" -o all-gcc -o maybe-all-gcc -o all-target-libgcc -o maybe-all-target-libgcc \
      CC_FOR_TARGET="$cc" GCC_FOR_TARGET="$cc" CXX_FOR_TARGET="$cxx" RAW_CXX_FOR_TARGET="$cxx" \
      all-target-libstdc++-v3
    # install-target-libstdc++-v3 depends on install-target-libgcc, which is not built here.
    rm -rf "$work/inst"
    make -C "$tuple/libstdc++-v3" DESTDIR="$work/inst" install
  } > "$work/log" 2>&1 || { tail -n 120 "$work/log"; echo "batch $(basename "$lines") failed" >&2; exit 1; }
  # The install treats the first variant of a batch as the default one: it also puts its libraries in
  # the root of lib and its c++config.h in the default bits directory. Only the variant of the root
  # (rv32i/ilp32, the first of the first batch of width 32) keeps those; the others keep just their
  # own directories, so no batch overwrites what another installed.
  if [ "$width" = 64 ] || ! grep -q '^\.;' "$lines"; then
    find "$work/inst$prefix/$tuple/lib" -maxdepth 1 -type f \( -name 'libstdc++*' -o -name 'libsupc++*' \) -delete
    find "$work"/inst"$prefix/$tuple"/include/c++/*/"$tuple" -mindepth 1 -maxdepth 1 ! -name 'rv*' -exec rm -rf {} +
  fi
  cp -a "$work/inst/." "$dest/"
  rm -rf "$work/inst"
  cd /
  echo "batch $(basename "$lines"): $n variants in $(( $(date +%s) - start )) s"
done
