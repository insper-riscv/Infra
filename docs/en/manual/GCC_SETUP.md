# Building the RISC-V GCC

How to build the RISC-V GCC from source and install it into the shared
cache `/opt/riscv-foundation`, on Debian-like (`apt`) and RHEL-like
(`dnf`/`yum`) distros. The build produces these binaries (all with the
`riscv32-unknown-elf-` prefix, omitted below) and libraries:

| Component | Role |
| :--- | :--- |
| `as` | Assembler |
| `ld`, `ld.bfd` | Linker |
| `ar`, `ranlib` | Creates and indexes static libraries (`.a`) |
| `objcopy` | Copies/converts a binary between formats (e.g. ELF to raw binary) |
| `objdump` | Disassembles a binary into assembly, lists sections and symbols |
| `nm` | Lists a binary's symbols |
| `readelf` | Inspects an ELF's internal structure |
| `addr2line` | Translates a memory address into a source file/line |
| `elfedit` | Edits fields of an ELF header |
| `size` | Shows the size of each section of a binary |
| `strings` | Lists human-readable text sequences inside a binary |
| `strip` | Removes symbols/debug info from a binary |
| `gcc`, `cpp` | C compiler and preprocessor |
| `g++`, `c++` | C++ compiler |
| `gcc-ar`, `gcc-nm`, `gcc-ranlib` | LTO-aware variants of `ar`/`nm`/`ranlib` |
| `gcov`, `gcov-dump`, `gcov-tool` | Code coverage |
| `lto-dump` | Inspects LTO information inside an object |
| `gdb` | Debugger: single-steps, breakpoints, reads registers and memory, against a remote target (simulator or hardware via JTAG/debug module) |
| `gdb-add-index` | Generates a symbol index for `gdb` to load faster |
| `gstack` | Prints the stack trace of a running process, via `gdb` |
| `run` | The only native host binary (not RISC-V) in the list: runs a compiled RISC-V binary under a simulator, relaying picolibc's semihosting I/O |
| picolibc (`libc.a` + headers) | Bare-metal C library, built for each variant of section 3.1: covers `printf`, `scanf`, `malloc` and `free` without depending on an operating system |

## 1. Dependencies

The build needs a C/C++ compiler, GNU build tools, the development
libraries GCC itself uses (GMP, MPFR, MPC), and `meson`, which builds
picolibc. The toolchain's submodules (binutils, gcc, picolibc, gdb) are
downloaded in section 2, so `git` and `curl` are also needed.

### 1.1. Debian-like (`apt`)

```bash
sudo apt-get install -y autoconf automake autotools-dev curl python3 \
  libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
  gperf libtool patchutils bc zlib1g-dev libexpat1-dev meson ninja-build git \
  cmake libglib2.0-dev expect device-tree-compiler libslirp-dev libzstd-dev \
  libncurses-dev
```

Check what is already installed:
```bash
dpkg -s autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev \
  libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
  patchutils bc zlib1g-dev libexpat1-dev meson ninja-build git cmake \
  libglib2.0-dev expect device-tree-compiler libslirp-dev libzstd-dev \
  libncurses-dev
```

The `expat` package usually shows up as `libexpat-dev` in the
riscv-gnu-toolchain documentation, but on Debian-based distros the one
that actually provides that file is `libexpat1-dev` (`libexpat-dev` is
just a virtual name it provides); `dpkg -s libexpat-dev` will not find the
package even with it installed, which is why the check above already uses
the real name.

### 1.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are
equivalent.

```bash
sudo dnf install -y autoconf automake curl git python3 libmpc-devel \
  mpfr-devel gmp-devel gawk bison flex texinfo patchutils gcc gcc-c++ \
  zlib-devel expat-devel libslirp-devel ncurses-devel meson ninja-build cmake
```

If any `-devel`, `texinfo`, `meson` or `ninja-build` package is not found,
the repository that holds it is disabled (`ninja-build`, in particular,
may require EPEL): enable `crb` (RHEL, Rocky, Alma 9) or `powertools` (8)
and retry:
```bash
sudo dnf config-manager --set-enabled crb   # or powertools
```

Check what is already installed:
```bash
rpm -q autoconf automake curl git python3 libmpc-devel mpfr-devel gmp-devel \
  gawk bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel \
  libslirp-devel ncurses-devel meson ninja-build cmake
```

## 2. Create the cache directory and the source

`/opt/riscv-foundation` is a single cache directory, so nobody needs to
keep their own copy of the large RISC-V toolchains. `/opt` itself is
standard FHS (Filesystem Hierarchy Standard) for manually installed/add-on
software, outside the distro's package manager; the `riscv-foundation`
subfolder name is a suggested convention, adjust it to your machine's
setup. GCC lives in `/opt/riscv-foundation/riscv32-elf`, and the `.tag`
file inside it holds the commit hash of the
[riscv-collab/riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
that produced its contents; that is the file that decides whether the
cache is up to date.

Who creates and maintains this directory changes depending on the
machine. On a workstation that has the `runner` user (see
[RUNNER_SETUP.md](../RUNNER_SETUP.md), section 3), the cache is shared by
the users of the machine and belongs to `runner`, so it can be updated
without `sudo`. On a test machine, without that
user, the path is still `/opt/riscv-foundation`, just created and
maintained a different way (section 2.2).

### 2.1. Workstation with a runner

The directory needs to exist owned by `runner:runner` and setgid, so the
`runner` user and anyone in its group can write to it without `sudo`. On a
machine that already has the runner configured it already exists;
otherwise:

```bash
sudo mkdir -p /opt/riscv-foundation
sudo chown runner:runner /opt/riscv-foundation
sudo chmod 2775 /opt/riscv-foundation
```

### 2.2. Test machine, without the `runner` user

Without `runner` to own the directory, and without another concurrent
process writing to it, the group/setgid scheme from section 2.1 has
nothing to solve: since it is a global binary, the build always runs via
`sudo` (never as a regular user), so the owner already comes out
`root:root` from `mkdir` itself, with no need for `chown`. `755` (owner
can write, everyone can read and execute) already leaves the installed
toolchain usable by any user on the machine:

```bash
sudo mkdir -p /opt/riscv-foundation
sudo chmod 755 /opt/riscv-foundation
```

### 2.3. Clone or update the source

This script and the one in section 3 run as whichever owner was chosen in
sections 2.1/2.2:

- **Workstation (section 2.1)**: as the `runner` user (or someone in its
  group), so the cache's owner stays consistent:
  ```bash
  sudo -u runner bash -c '<script>'
  ```
- **Test machine (section 2.2)**: since the directory is owned by `root`,
  via `sudo`:
  ```bash
  sudo bash -c '<script>'
  ```

The source lives in `/opt/riscv-foundation/riscv-gnu-toolchain`, next to
the cache's `riscv32-elf`. If `SRC_DIR` does not exist yet, the script
clones the repository's default branch; if it already exists from a
previous run, it does a `pull` to bring in new commits, without needing to
reclone:

```bash
set -euo pipefail
SRC_DIR=/opt/riscv-foundation/riscv-gnu-toolchain

if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" pull --ff-only
else
  git clone https://github.com/riscv-collab/riscv-gnu-toolchain "$SRC_DIR"
fi
git -C "$SRC_DIR" submodule sync --recursive
git -C "$SRC_DIR" submodule update --init --depth 1 binutils gcc gdb picolibc
```

Only the four submodules used by the build are downloaded, each with
`--depth 1`, without the full history. The rest (newlib, glibc, musl, llvm,
qemu, spike, pk, dejagnu, uclibc-ng) are left out. The result takes about
2.9 GB and stays on disk permanently in `SRC_DIR`.

## 3. Build and install into the cache

### 3.1. Variants

The build produces a library for each of these variants. A library built for fewer extensions runs on a core
with more of them, and not the other way around; the compiler takes the largest variant that is a subset of
the `-march` it is given.

| `-march` | `-mabi` | Integer multiply and divide | Floating point |
| :--- | :--- | :--- | :--- |
| `rv32i` | `ilp32` | in software | in software |
| `rv32i_zmmul` | `ilp32` | multiply in hardware, divide in software | in software |
| `rv32im` (the default) | `ilp32` | in hardware | in software |
| `rv32imf` | `ilp32f` | in hardware | single precision in hardware |
| `rv32imfd` | `ilp32d` | in hardware | single and double precision in hardware |

### 3.2. Build

Run as the same owner as in section 2.3. With `SRC_DIR` already updated, this step checks whether the cache
needs updating and, if so, builds and installs:

```bash
set -euo pipefail
CACHE_DIR=/opt/riscv-foundation/riscv32-elf
SRC_DIR=/opt/riscv-foundation/riscv-gnu-toolchain
MULTILIB="rv32i-ilp32--;rv32i_zmmul-ilp32--;rv32im-ilp32--;rv32imf-ilp32f--;rv32imfd-ilp32d--"
COMMIT=$(git -C "$SRC_DIR" rev-parse HEAD)

if [ "$(cat "$CACHE_DIR/.tag" 2>/dev/null)" = "$COMMIT" ]; then
  echo "Cache is already at $COMMIT, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp riscv-gcc-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
cd "$BUILD_DIR"

rm -rf "$CACHE_DIR" && mkdir -p "$CACHE_DIR"

# binutils and GDB, with the Makefile of riscv-gnu-toolchain
"$SRC_DIR/configure" --prefix="$CACHE_DIR" --with-arch=rv32im --enable-picolibc
make -j"$(nproc)" stamps/build-binutils-picolibc stamps/build-gdb-picolibc

# the compiler, and libgcc for every variant
mkdir gcc && cd gcc
"$SRC_DIR/gcc/configure" --target=riscv32-unknown-elf --prefix="$CACHE_DIR" \
  --disable-shared --disable-threads --with-system-zlib --enable-tls \
  --with-newlib --with-picolibc --with-sysroot="$CACHE_DIR/riscv32-unknown-elf" \
  --disable-libmudflap --disable-libssp --disable-libquadmath --disable-libgomp \
  --disable-nls --disable-tm-clone-registry --src="$SRC_DIR/gcc" \
  --with-multilib-generator="$MULTILIB" \
  --with-arch=rv32im --with-abi=ilp32 --with-isa-spec=20191213 \
  --enable-languages=c,c++ \
  CFLAGS_FOR_TARGET="-Os -mcmodel=medlow" CXXFLAGS_FOR_TARGET="-Os -mcmodel=medlow"
make -j"$(nproc)" all-gcc
make install-gcc
make -j"$(nproc)" all-target-libgcc
make install-target-libgcc
cd ..

# picolibc, compiled with that compiler for every variant
export PATH="$CACHE_DIR/bin:$PATH"
tool=riscv32-unknown-elf
cat > cross.txt <<EOF
[binaries]
c = ['$tool-gcc', '-nostdlib']
cpp = ['$tool-g++', '-nostdlib']
ar = '$tool-ar'
as = '$tool-as'
nm = '$tool-nm'
strip = '$tool-strip'
[host_machine]
system = 'unknown'
cpu_family = 'riscv32'
cpu = 'riscv32'
endian = 'little'
[properties]
c_args = ['-msave-restore', '-fno-common', '-mcmodel=medlow']
cpp_args = ['-msave-restore', '-fno-common', '-mcmodel=medlow']
skip_sanity_check = true
EOF
meson setup picolibc "$SRC_DIR/picolibc" --cross-file cross.txt --buildtype=minsize \
  --prefix="$CACHE_DIR/$tool" -Dincludedir=include -Dlibdir=lib \
  -Dsysroot-install=true -Dsystem-libc=true -Dtests=false
ninja -C picolibc install

echo "$COMMIT" > "$CACHE_DIR/.tag"
```

The script has four stages.

| Stage | What it does |
| :--- | :--- |
| binutils and GDB | The Makefile of riscv-gnu-toolchain builds and installs them for the `riscv32-unknown-elf` target; `--with-arch=rv32im` makes it derive that target and the `ilp32` ABI, and without it the default target is RV64GC (`riscv64-unknown-elf-*`) |
| compiler | `gcc/configure` is run directly, because the picolibc rule of the Makefile disables multilib; `--with-multilib-generator` takes the variants as `<arch>-<abi>--` separated by `;` and implies multilib, and `--with-arch`/`--with-abi` set the default variant |
| `libgcc` | Built with the compiler of the previous stage, once for each variant |
| picolibc | Built by `meson` with that compiler; it reads the variants from the compiler and builds a library for each one, installing them into the sysroot |

- The build runs out-of-tree from the source, in `/var/tmp`: this allows reconfiguring/rebuilding without
  dirtying `SRC_DIR`; `/tmp` is often tmpfs, too small for the build tree.
- `.tag` is written last: an interrupted build leaves the cache without `.tag`, so the next run rebuilds
  instead of trusting an incomplete cache.
- The `CFLAGS_FOR_TARGET` `-mcmodel=medlow` is the code model of the compiler and of picolibc; both must use
  the same one.

The build adds the compilation tree, deleted at the end in `/var/tmp`. To adopt a new riscv-gnu-toolchain
release, run the commands from sections 2.3 and 3.2 again.

### 3.3. Reduce the size (optional)

The host programs of the install (compiler, linker and the rest) carry their symbols, which are most of its
size. Removing them takes the install from about 2.3 GB to under 0.5 GB and does not change what the
toolchain produces:

```bash
CACHE_DIR=/opt/riscv-foundation/riscv32-elf
find "$CACHE_DIR/bin" "$CACHE_DIR/libexec" "$CACHE_DIR/riscv32-unknown-elf/bin" -type f -perm /111 \
  -exec sh -c 'for f; do [ "$(head -c 4 "$f" | tail -c 3)" = ELF ] && strip --strip-unneeded "$f"; done; true' sh {} +
```

## 4. Verify

```bash
CACHE=/opt/riscv-foundation/riscv32-elf
cat "$CACHE/.tag"
"$CACHE/bin/riscv32-unknown-elf-gcc" --version
"$CACHE/bin/riscv32-unknown-elf-gcc" -print-multi-lib
```

The last command should print five lines, one for each variant of section 3.1 (the default is the root, `.`).
To see which library a `-march` takes:

```bash
"$CACHE/bin/riscv32-unknown-elf-gcc" -march=rv32i -mabi=ilp32 --specs=picolibc.specs -print-file-name=libc.a
```

To check that no picolibc code of the default variant uses instructions the RV32IM core does not implement
(CSR, atomics), the toolchain's own `objdump` reads `crt0.o` (the startup runtime) and `libc.a`:

```bash
"$CACHE/bin/riscv32-unknown-elf-objdump" -d "$CACHE/riscv32-unknown-elf/lib/crt0.o" \
  | grep -E 'csrr|csrw|lr\.w|sc\.w|amo'
"$CACHE/bin/riscv32-unknown-elf-objdump" -d "$CACHE/riscv32-unknown-elf/lib/libc.a" \
  | grep -E 'csrr|csrw|lr\.w|sc\.w|amo'
```

Neither search should return anything: a plain `rv32im` requires neither Zicsr nor the A (atomics) extension.

## 5. Global PATH

Adds the GCC binaries to the global `PATH`, by creating a wrapper for
each one in `/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/riscv32-elf/bin/riscv32-unknown-elf-*; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  sudo rm -f "/usr/local/bin/$name"
  sudo tee "/usr/local/bin/$name" >/dev/null <<EOF
#!/bin/sh
exec "$f" "\$@"
EOF
  sudo chmod 755 "/usr/local/bin/$name"
done
```

Verify:
```bash
which riscv32-unknown-elf-gcc
```

Only needs to run again if a new release adds a binary with a new name;
the existing ones keep pointing to the same path.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
