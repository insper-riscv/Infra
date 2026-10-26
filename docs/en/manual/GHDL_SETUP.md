# Building GHDL

GHDL with the LLVM backend, built from source from the latest `6.x.y` release of `ghdl/ghdl` and installed in `/opt/ghdl`. The LLVM backend runs on x86-64 and on ARM, which the `mcode` backend does not, so a simulation behaves the same on both. The build produces:

| Component | Role |
| :--- | :--- |
| `ghdl` | Analyzer, elaborator and simulator of VHDL |
| `ghdl1-llvm` | The LLVM code generator that `ghdl` calls |
| `ghwdump` | Dumps a GHW waveform file as text |
| `lib` | The compiled VHDL libraries, such as `ieee` and `std` |

## 1. Dependencies

### 1.1. Debian-like (`apt`)

The commands were run on Ubuntu 26.04.

```bash
sudo apt-get install -y ca-certificates git make gcc g++ clang gnat llvm-dev \
  zlib1g-dev libedit-dev
```

### 1.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are equivalent. The commands were run on Rocky Linux 9.

GHDL is written in Ada, so it needs GNAT. On Rocky Linux 9 the `gcc-gnat` package of EPEL does not install (`dnf install gcc-gnat` installs only `gcc`), and on Rocky Linux 10 it is not in the repositories, so this build was not run on them. The list below was run on Fedora, which needs neither `crb` nor EPEL; `diffutils` provides the `cmp` that `configure` asks for. The Docker image [`base-ghdl`](../docker/base-ghdl.md) has GHDL already built.

```bash
sudo dnf install -y ca-certificates git make gcc gcc-c++ clang gcc-gnat llvm-devel \
  zlib-devel libedit-devel diffutils
```

## 2. Build and install

Run the script as root (for example with `sudo -i`): it writes into `/opt` and, where noted, into `/usr/local/bin` and `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/ghdl
TAG=$(git ls-remote --tags --refs https://github.com/ghdl/ghdl 'v6.*' | sed 's|.*refs/tags/||' \
      | grep -E '^v6\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$TAG" ]; then
  echo "GHDL is already at $TAG, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp ghdl-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT

git clone --depth 1 --branch "$TAG" https://github.com/ghdl/ghdl "$BUILD_DIR/src"
mkdir "$BUILD_DIR/build" && cd "$BUILD_DIR/build"
"$BUILD_DIR/src/configure" --with-llvm-config --prefix="$PREFIX"
make -j"$(nproc)"
rm -rf "$PREFIX"
make install
echo "$TAG" > "$PREFIX/.tag"
```

- `--with-llvm-config` selects the LLVM backend, which elaborates a design into an executable: use `ghdl -a`, `ghdl -e` and `ghdl -r` (or `ghdl --elab-run`), never a bare `ghdl -r` after only `-a`.
- The build runs in `/var/tmp`, not in `/tmp`, which is often a tmpfs too small for the build tree, and the directory is deleted at the end.
- `.tag` is written last: an interrupted build leaves the install without `.tag`, so the next run rebuilds instead of trusting an incomplete install, and a run at the version already installed does nothing.

To update, run the script of section 2 again.

## 3. Verify

```bash
d=$(mktemp -d); cd "$d"
cat > t.vhd <<'EOF'
library ieee; use ieee.std_logic_1164.all;
entity t is end;
architecture a of t is signal s : std_logic_vector(3 downto 0) := (others => '1'); begin
  process begin assert s = "1111" report "bad" severity failure; report "ghdl ok"; wait; end process;
end;
EOF
/opt/ghdl/bin/ghdl --version | head -n 1
/opt/ghdl/bin/ghdl -a --std=08 t.vhd
/opt/ghdl/bin/ghdl --elab-run --std=08 t
cd /; rm -rf "$d"
```

## 4. Global PATH

Adds the binaries to the global `PATH`, by creating a wrapper for each one in `/usr/local/bin`:

```bash
for f in /opt/ghdl/bin/*; do
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

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
