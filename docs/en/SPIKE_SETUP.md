# Building Spike

The Spike build (`riscv-software-src/riscv-isa-sim`) produces these
binaries and libraries:

| Component | Role |
| :--- | :--- |
| `spike` | The RISC-V reference simulator itself: runs a compiled binary and reports the state of memory/registers |
| `spike-dasm` | Disassembles chunks of RISC-V machine code into assembly |
| `elf2hex` | Converts an ELF binary into a hex file, the format used by FPGA boot memories (BRAM) |
| `xspike` | Spike's graphical (X11) front-end |
| `termios-xspike` | Serial-terminal variant of `xspike` |
| `spike-log-parser` | Parses the execution log Spike produces |
| `libfesvr` | The "front-end server" library: loads the ELF, implements the syscalls the simulated binary calls |
| `libriscv` | The simulation's core library: decodes and executes RISC-V instructions |
| `libdisasm` | Disassembly library used by `spike-dasm` and by Spike itself |
| `libsoftfloat` | Software floating-point library, used by the simulation of the F/D/Q extensions |

## 1. Dependencies

### 1.1. Install `uv` globally

Via the official installer (`https://astral.sh/uv/install.sh`), pointed at
`/usr/local/bin` instead of the default `~/.local/bin`: this way it is
available to any user on the machine, with no extra PATH needed
(`/usr/local/bin` is already on everyone's default `PATH`).

```bash
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh
chmod +x /tmp/uv-install.sh
sudo UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 /tmp/uv-install.sh
rm /tmp/uv-install.sh
```

- Downloads the script first instead of `curl | sudo sh` directly: lets
  you inspect it before running as root.
- The installer downloads a pre-built binary (compiles nothing) and checks
  its SHA256 against a fixed hash baked into the script before installing.
- `UV_NO_MODIFY_PATH=1`: no need to modify anyone's `~/.bashrc`, since
  `/usr/local/bin` is already on the `PATH`.

Verify:
```bash
which uv        # /usr/local/bin/uv
uv --version
```

Update later, when needed (needs `sudo` for the same reason as the
install: `/usr/local/bin` is owned by `root`):
```bash
sudo uv self update
```

### 1.2. Dependencies for building Spike

Spike is cloned and built from source, it does not come pre-built. This
needs `git` to fetch the source (not installed by default on every
distro/minimal image), and Spike's `./configure` **fails without
`device-tree-compiler`**; the Boost packages avoid a slower `make` with
warnings.

#### 1.2.1. Debian-like (`apt`)

```bash
sudo apt-get install -y git device-tree-compiler libboost-regex-dev libboost-system-dev
```

Check what is already installed before running `apt-get install`:
```bash
dpkg -s git device-tree-compiler libboost-regex-dev libboost-system-dev
```

#### 1.2.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are
equivalent.

```bash
sudo dnf install -y git dtc boost-devel boost-regex boost-system
```

Spike's official README only documents swapping in `dtc` for
`device-tree-compiler` on `yum`; the Boost packages are not mentioned there
for `yum`/`dnf`, so `boost-devel` (headers) plus
`boost-regex`/`boost-system` (libraries) are the RHEL equivalents of the
`apt` packages above.

If `boost-devel` or `dtc` are not found, the repository that holds them is
disabled: enable `crb` (RHEL, Rocky, Alma 9) or `powertools` (8) and
retry:
```bash
sudo dnf config-manager --set-enabled crb   # or powertools
```

Check what is already installed:
```bash
rpm -q git dtc boost-devel boost-regex boost-system
```

## 2. Create the cache directory and the source

`/opt/riscv-foundation` is a single cache directory, so nobody needs to
keep their own copy of the large RISC-V toolchains. `/opt` itself is
standard FHS (Filesystem Hierarchy Standard) for manually installed/add-on
software, outside the distro's package manager; the `riscv-foundation`
subfolder name is a suggested convention, adjust it to your machine's
setup. Spike lives in `/opt/riscv-foundation/spike`, and the `.tag` file
inside it holds the commit hash of
[riscv-software-src/riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim)
that produced its contents; that is the file that decides whether the
cache is up to date.

Who creates and maintains this directory changes depending on the
machine. On a workstation with the self-hosted GitHub Actions runner
already configured (see [RUNNER_SETUP.md](RUNNER_SETUP.md), Phase 1), the
cache is shared by every user and repository that goes through that
runner, and the `runner` user itself needs to be able to update it alone,
with no `sudo` available inside a job. On a test machine, without that
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
Spike usable by any user on the machine:

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

The source lives in `/opt/riscv-foundation/riscv-isa-sim`, next to the
cache's `spike`. If `SRC_DIR` does not exist yet, the script clones the
repository's default branch; if it already exists from a previous run, it
does a `pull` to bring in new commits, without needing to reclone. Either
way, the script ends by moving Spike's debug module from address `0x0` to
`0x70000000`; before the `pull` it reverts that edit so it cannot conflict
with upstream:

```bash
set -euo pipefail
SRC_DIR=/opt/riscv-foundation/riscv-isa-sim

if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" checkout -- riscv/platform.h
  git -C "$SRC_DIR" pull --ff-only
else
  git clone https://github.com/riscv-software-src/riscv-isa-sim "$SRC_DIR"
fi
sed -i "s/^#define DEBUG_START .*/#define DEBUG_START        0x70000000/" "$SRC_DIR/riscv/platform.h"
```

## 3. Build and install into the cache

Run as the same owner as in section 2.3. With `SRC_DIR` already updated,
this step checks whether the cache needs updating and, if so, builds and
installs:

```bash
set -euo pipefail
CACHE_DIR=/opt/riscv-foundation/spike
SRC_DIR=/opt/riscv-foundation/riscv-isa-sim
TAG="$(git -C "$SRC_DIR" rev-parse HEAD)-debug-start"

if [ "$(cat "$CACHE_DIR/.tag" 2>/dev/null)" = "$TAG" ]; then
  echo "Cache is already at $TAG, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp riscv-isa-sim-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
cd "$BUILD_DIR"

rm -rf "$CACHE_DIR" && mkdir -p "$CACHE_DIR"
"$SRC_DIR/configure" --prefix="$CACHE_DIR"
make -j"$(nproc)"
make install
echo "$TAG" > "$CACHE_DIR/.tag"
```

- `--prefix` points at the cache itself: `make` only compiles; installing
  the binaries there requires running `make install` afterward, as a
  second command.
- The build runs out-of-tree from the source, in `/var/tmp`: this allows
  reconfiguring/rebuilding without dirtying `SRC_DIR` with build artifacts; `/tmp` is often
  tmpfs, too small for the build tree.
- `DEBUG_START` (in `riscv/platform.h`) is the address where Spike places
  its debug module. With the default (`0x0`), Spike aborts at startup with
  `devices at [0, 1000) and [0, 10000) overlap` when the target's ROM starts
  at `0x0`. The `-debug-start` suffix on `.tag` makes a cache built without
  this edit get rebuilt.
- `.tag` is written last: an interrupted build leaves the cache without
  `.tag`, so the next run rebuilds instead of trusting an incomplete
  cache.

## 4. Verify

```bash
cat /opt/riscv-foundation/spike/.tag
/opt/riscv-foundation/spike/bin/spike --help
/opt/riscv-foundation/spike/bin/spike --isa=rv32im -m0x0:0x10000 --pc=0 \
  --disable-dtb /dev/null 2>&1 | grep overlap
```

`.tag` must end in `-debug-start`, and the `grep` must print nothing.

## 5. Global PATH

Adds the Spike binaries to the global `PATH`, by creating a wrapper for
each one in `/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/spike/bin/*; do
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
which spike
```

Only needs to run again if a new version adds a binary with a new name;
the existing ones keep pointing to the same path.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
