# Building GTKWave

GTKWave, the waveform viewer, built from source from the head of the `lts` branch (the 3.3 maintenance line) of `gtkwave/gtkwave`, GTK 3 tree, and installed in `/opt/gtkwave`. GTK 3 has a Wayland backend, so it runs on Wayland natively and on X11. The build produces:

| Component | Role |
| :--- | :--- |
| `gtkwave` | The viewer |
| `twinwave` | Two viewers in one window; uses XEmbed, which exists only on X11 |
| `rtlbrowse` | Browser of the RTL source |
| `vcd2fst`, `fst2vcd`, `vcd2lxt`, `lxt2vcd`, `vcd2lxt2`, `vcd2vzt`, `vzt2vcd`, `evcd2vcd` | Converters between waveform formats |
| `fstminer`, `lxt2miner`, `vztminer` | Extract signals from a dump |
| `json2stems`, `xml2stems` | Generate stems files for the RTL browser |
| `shmidcat` | Reads a dump from shared memory |

## 1. Dependencies

### 1.1. Debian-like (`apt`)

The commands were run on Ubuntu 26.04.

```bash
sudo apt-get install -y build-essential git ca-certificates pkg-config gperf flex \
  libgtk-3-dev libbz2-dev liblzma-dev libjudy-dev zlib1g-dev
```

### 1.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are equivalent. The commands were run on Rocky Linux 9.

Some packages are in the `crb` and EPEL repositories; enable them first:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

On RHEL itself, `epel-release` is not in the base repositories: enable EPEL as described in its [documentation](https://docs.fedoraproject.org/en-US/epel/).

```bash
sudo dnf install -y gcc gcc-c++ make git ca-certificates pkgconf-pkg-config gperf flex \
  gtk3-devel bzip2-devel xz-devel Judy-devel zlib-devel
```

## 2. Build and install

Run the script as root (for example with `sudo -i`): it writes into `/opt` and, where noted, into `/usr/local/bin` and `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/gtkwave
COMMIT=$(git ls-remote https://github.com/gtkwave/gtkwave refs/heads/lts | cut -f1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$COMMIT" ]; then
  echo "GTKWave is already at $COMMIT, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp gtkwave-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT

git clone --depth 1 --branch lts https://github.com/gtkwave/gtkwave "$BUILD_DIR/src"
cd "$BUILD_DIR/src/gtkwave3-gtk3"
CFLAGS="-O2 -std=gnu17 -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=int-conversion" \
  ./configure --prefix="$PREFIX" --enable-gtk3 --disable-tcl --disable-mime-update
make -j"$(nproc)"
rm -rf "$PREFIX"
make install
echo "$COMMIT" > "$PREFIX/.tag"
```

- `--enable-gtk3` builds the GTK 3 tree, `--disable-tcl` leaves out Tcl, which is not needed to view a waveform, and `--disable-mime-update` leaves the MIME database to the system.
- The `CFLAGS` keep three diagnostics of a current GCC (14 and later) as warnings, because the code of this tree uses callback signatures that those versions reject by default.
- A window needs a display: on Wayland, `libegl1`, `libegl-mesa0`, `libgl1`, `libgl1-mesa-dri`, `adwaita-icon-theme` and `shared-mime-info` are the run-time packages; a desktop installation already has them.
- The build runs in `/var/tmp`, not in `/tmp`, which is often a tmpfs too small for the build tree, and the directory is deleted at the end.
- `.tag` is written last: an interrupted build leaves the install without `.tag`, so the next run rebuilds instead of trusting an incomplete install, and a run at the version already installed does nothing.

To update, run the script of section 2 again.

## 3. Verify

```bash
ls /opt/gtkwave/bin
ldd /opt/gtkwave/bin/gtkwave | grep "not found" || echo "no missing library"
```

## 4. Global PATH

Adds the binaries to the global `PATH`, by creating a wrapper for each one in `/usr/local/bin`:

```bash
for f in /opt/gtkwave/bin/*; do
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
