#!/usr/bin/env bash
# Builds libsupc++ and libstdc++ of the RISC-V GCC for the library variants of one width, against the
# picolibc already installed in the prefix of that GCC, and installs them under DESTDIR. It is the C++
# stage of docker/base/picolibc/Dockerfile.
#
# The GCC of base-gcc is installed without its source or build tree, so the target libraries are
# configured from the gcc source of the same riscv-gnu-toolchain commit, with the installed compiler
# standing in for the one that would have been built. The variants are built in batches: each batch
# is configured, built, installed and its build tree deleted, so the disk holds one batch at a time
# for each batch that runs at once. Batches are independent of each other (each has its own build tree
# and install tree, and installs files no other batch installs), so <jobs> of them run at the same
# time, each with make -j<cores / jobs>: the make of one batch builds the variants one after the other
# and leaves most of a large machine idle.
# libatomic is not built, because GCC does not support it for a bare-metal ELF target.
#
#   scripts/cxx-libs.sh <width> <gcc-source> <prefix> <destdir> <batch-size> [<jobs>]
#
#   width        32 or 64: which variants of the compiler to build (for 32, the root of the library
#                directory and every rv32 variant; for 64, every rv64 variant)
#   gcc-source   the gcc directory of riscv-gnu-toolchain
#   prefix       where the GCC and picolibc are installed (/opt/riscv-foundation/riscv32-elf)
#   destdir      the root the libraries and headers are installed under
#   batch-size   how many variants are built before the build tree is deleted
#   jobs         how many batches are built at the same time (default 1), or auto for one batch
#                for every 7 cores of the machine (at least 1); the disk holds about 0.65 GB for
#                each variant of each batch running
set -euo pipefail

[ "$#" -eq 5 ] || [ "$#" -eq 6 ] || { echo "usage: $0 <width> <gcc-source> <prefix> <destdir> <batch-size> [<jobs>]" >&2; exit 2; }
width="$1"; src="$2"; prefix="$3"; dest="$4"; batch="$5"; jobs="${6:-1}"
if [ "$jobs" = auto ]; then
  jobs=$(( $(nproc) / 7 ))
  [ "$jobs" -ge 1 ] || jobs=1
fi
case "$jobs" in ''|*[!0-9]*|0) echo "jobs must be a positive integer or auto" >&2; exit 2 ;; esac
threads=$(( $(nproc) / jobs ))
[ "$threads" -ge 1 ] || threads=1
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

# The archives are made deterministic: ar and ranlib run in the D mode (no timestamp, owner or file mode
# in the archive), so the same objects give the same libstdc++.a, libstdc++exp.a and libsupc++.a on
# any machine and on any day. libtool calls $AR with its own flags (cru), so the wrapper adds D to the
# operation letters instead of relying on AR_FLAGS.
cat > "$work/wrap/wrap-ar" <<WRAP
#!/bin/bash
# libtool calls: ar --plugin <lto plugin> cru <archive> <objects>; D goes on the operation letters.
args=()
done=0
for arg in "\$@"; do
  if [ "\$done" = 0 ] && [[ "\$arg" =~ ^-?[a-zA-Z]+\$ ]] && [[ "\$arg" != -[Vh] ]]; then
    arg="\${arg}D"; done=1
  fi
  args+=("\$arg")
done
exec $tool-ar "\${args[@]}"
WRAP
cat > "$work/wrap/wrap-ranlib" <<WRAP
#!/bin/bash
exec $tool-ranlib -D "\$@"
WRAP
chmod +x "$work/wrap/wrap-ar" "$work/wrap/wrap-ranlib"

# The configure of the target libraries takes ar and ranlib from the build-time tools directory and
# writes them into libtool, so the variable AR_FOR_TARGET alone does not reach the archives. A copy of
# that directory (links) with the two wrappers in place of ar and ranlib is what the configure gets.
mkdir "$work/btt"
for f in "$prefix/$tuple/bin"/*; do ln -s "$f" "$work/btt/$(basename "$f")"; done
ln -sf "$work/wrap/wrap-ar" "$work/btt/ar"
ln -sf "$work/wrap/wrap-ranlib" "$work/btt/ranlib"

"$tool-gcc" -print-multi-lib | grep -E "$pick" > "$work/all.txt"
total="$(wc -l < "$work/all.txt")"
split -l "$batch" -d "$work/all.txt" "$work/batch."
echo "libstdc++ for $total variants of width $width, in batches of $batch"

cc="$work/wrap/wrap-gcc"
cxx="$work/wrap/wrap-g++"
ar="$work/wrap/wrap-ar"
ranlib="$work/wrap/wrap-ranlib"
# Builds and installs one batch (the file of its lines) in a build tree of its own, then copies it into
# destdir. It runs in a subshell, so the directory and the variable it sets stay in that batch.
build_batch() (
  lines="$1"
  id="$(basename "$lines")"
  n="$(wc -l < "$lines")"
  start="$(date +%s)"
  dir="$work/run.$id"
  mkdir "$dir" "$dir/build"
  export CXX_BATCH_LINES="$lines"
  cd "$dir/build"
  {
    "$src/configure" --target="$tuple" --prefix="$prefix" \
      --disable-shared --disable-threads --with-system-zlib --enable-tls --with-newlib --with-picolibc \
      --with-sysroot="$prefix/$tuple" \
      --disable-libmudflap --disable-libssp --disable-libquadmath --disable-libgomp --disable-nls \
      --disable-tm-clone-registry \
      --with-arch=rv32i --with-abi=ilp32 --with-isa-spec=20191213 --enable-languages=c,c++ \
      --with-build-time-tools="$work/btt" \
      CC_FOR_TARGET="$cc" CXX_FOR_TARGET="$cxx" AR_FOR_TARGET="$ar" RANLIB_FOR_TARGET="$ranlib" \
      CFLAGS_FOR_TARGET="-Os -mcmodel=$cmodel" CXXFLAGS_FOR_TARGET="-Os -mcmodel=$cmodel"
    # The compiler targets are marked as up to date (-o), so make does not build the GCC, and the
    # compilers are given on the command line because the configure values do not reach the rules.
    make -j"$threads" -o all-gcc -o maybe-all-gcc -o all-target-libgcc -o maybe-all-target-libgcc \
      CC_FOR_TARGET="$cc" GCC_FOR_TARGET="$cc" CXX_FOR_TARGET="$cxx" RAW_CXX_FOR_TARGET="$cxx" \
      AR_FOR_TARGET="$ar" RANLIB_FOR_TARGET="$ranlib" \
      all-target-libstdc++-v3
    # install-target-libstdc++-v3 depends on install-target-libgcc, which is not built here.
    make -C "$tuple/libstdc++-v3" DESTDIR="$dir/inst" install
  } > "$dir/log" 2>&1 || { tail -n 120 "$dir/log"; echo "batch $id failed" >&2; exit 1; }
  # The install treats the first variant of a batch as the default one: it also puts its libraries in
  # the root of lib and its c++config.h in the default bits directory. Only the variant of the root
  # (rv32i/ilp32, the first of the first batch of width 32) keeps those; the others keep just their
  # own directories, so no batch overwrites what another installed.
  if [ "$width" = 64 ] || ! grep -q '^\.;' "$lines"; then
    find "$dir/inst$prefix/$tuple/lib" -maxdepth 1 -type f \( -name 'libstdc++*' -o -name 'libsupc++*' \) -delete
    find "$dir"/inst"$prefix/$tuple"/include/c++/*/"$tuple" -mindepth 1 -maxdepth 1 ! -name 'rv*' -exec rm -rf {} +
  fi
  # One batch at a time writes into destdir: the batches share parent directories and the headers
  # every batch installs with the same content.
  flock "$work/merge.lock" cp -a "$dir/inst/." "$dest/"
  rm -rf "$dir"
  echo "batch $id: $n variants in $(( $(date +%s) - start )) s"
)

# At most <jobs> batches run at once, each in a process group of its own (set -m), so that stopping one
# stops the make and the compilers under it too. The first batch that fails stops the others and the script.
set -m
failed=0
pids=()
for lines in "$work"/batch.*; do
  while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do
    wait -n || failed=1
    [ "$failed" = 0 ] || break 2
  done
  build_batch "$lines" &
  pids+=("$!")
done
while [ "$failed" = 0 ] && [ -n "$(jobs -rp)" ]; do
  wait -n || failed=1
done
if [ "$failed" != 0 ]; then
  for pid in "${pids[@]}"; do kill -- "-$pid" 2>/dev/null || true; done
  wait || true
  exit 1
fi
