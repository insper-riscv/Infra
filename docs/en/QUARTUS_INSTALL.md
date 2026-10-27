# Installing Quartus Prime Lite

Quartus needs to be installed directly under `/opt`, as a global program
(`/opt/altera_lite`, instead of a user's home), to be reachable by any
user/service on the machine without a special group (for example, the
self-hosted runner described in [RUNNER_SETUP.md](RUNNER_SETUP.md)). Since
the destination is `/opt`, owned by `root`, the install needs `sudo`.

## 1. Download the official installer

Quartus Prime Lite Edition, version 25.1:
[download page](https://www.altera.com/downloads)

The file name changes with every build (e.g. `qinst-lite-linux-25.1std-1129.run`).
The commands below use `qinst-lite-linux-*.run` to avoid depending on the
exact number; check the SHA1 published on the download page against the
downloaded file before installing.

## 2. Grant execute permission

```bash
chmod +x qinst-lite-linux-*.run
```

## 3. Install

**GUI mode** (runs the installer directly):
```bash
sudo ./qinst-lite-linux-*.run
```
On the destination screen, point it to `/opt/altera_lite`. `sudo` is needed
because `/opt` belongs to `root`; without it, the installer cannot create
the destination directory.

**CLI mode** (no display, e.g. headless/SSH machine):
```bash
sudo ./qinst-lite-linux-*.run -- --target /opt/altera_lite
sudo /opt/altera_lite/qinst.sh --cli   # --help to see the options
```

## 4. Expected result

Binaries in `/opt/altera_lite/25.1std/quartus/bin/`, owned by `root:root`,
`755`/`555` permissions (read+execute for everyone, write only for root).

## 5. Global PATH

Adds the Quartus binaries (`quartus`, `quartus_pgm`, `jtagconfig`, etc.) to
the global `PATH`, by creating a wrapper for each one in `/usr/local/bin`:

```bash
QUARTUS_ROOTDIR=/opt/altera_lite/25.1std/quartus
for f in "$QUARTUS_ROOTDIR"/bin/*; do
  name=$(basename "$f")
  sudo rm -f "/usr/local/bin/$name"
  sudo tee "/usr/local/bin/$name" >/dev/null <<EOF
#!/bin/sh
export QUARTUS_ROOTDIR_OVERRIDE=$QUARTUS_ROOTDIR
exec "$f" "\$@"
EOF
  sudo chmod 755 "/usr/local/bin/$name"
done
```

Verify:
```bash
which quartus
bash -c 'quartus_pgm --version'
```

## 6. (Optional) Global `.desktop` shortcut

For Quartus to show up in any user's application menu:

```bash
sudo tee /usr/share/applications/quartus-lite.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Quartus Prime Lite
Comment=Intel/Altera Quartus Prime Lite Edition
Exec=/opt/altera_lite/25.1std/quartus/bin/quartus
Icon=/opt/altera_lite/25.1std/quartus/adm/quartusii.png
Terminal=false
Categories=Development;Electronics;
StartupWMClass=quartus
EOF
sudo update-desktop-database /usr/share/applications
```

It needs to live in `/usr/share/applications/`, not
`~/.local/share/applications/` (which only applies to the current user).
`desktop-file-validate` checks that the file is syntactically correct:

```bash
desktop-file-validate /usr/share/applications/quartus-lite.desktop
```

## 7. Using Quartus from a container

The CI images do not include Quartus. They have the system library the command-line tools of Quartus link against (`libglib2.0-0t64`), so the installation on the host can be mounted into a container and run there.

The Quartus of the host (here `/opt/altera_lite/25.1std`) is mounted read-only and put on the `PATH` inside the container. The USB-Blaster is reached through the JTAG server (`jtagd`) of the host, which the container sees by sharing the host network:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp/h \
  -v "$PWD:/workspace" -v /opt/altera_lite:/opt/altera_lite:ro \
  ghcr.io/insper-riscv/ci-elf:latest bash -c '
    export PATH=/opt/altera_lite/25.1std/quartus/bin:$PATH
    jtagconfig
    cd platforms/sdram-bringup/quartus && quartus_sh --flow compile sdram_bringup'
```

| Option | Why |
| :--- | :--- |
| `-v /opt/altera_lite:/opt/altera_lite:ro` | the Quartus installation, read-only; the image carries none |
| `--network host` | `jtagd` listens on `localhost:1309` of the host, and the programmer and `quartus_stp` of the container connect to it there |
| `--user "$(id -u):$(id -g)"` and `-e HOME=/tmp/h` | the files the build writes belong to the invoking user, and Quartus has a writable home |

`jtagd` must be running on the host, and it can stop on its own between two uses. Run `jtagconfig` on the host right before the container: it starts `jtagd` if none is running. Without a `jtagd` on the host, the container starts one of its own, which cannot see the USB, and `jtagconfig` inside the container prints:

```text
1) USB-Blaster variant [3-5]
  Unable to lock chain - Bad port name
```

With the host `jtagd` running, the same command prints the cable and the chip (`USB-Blaster [3-5]`, `02B050DD 5CE(BA4|FA4)` on the DE0-CV). On a Docker daemon with user-namespace remapping, `--network host` is refused unless the run also has `--userns=host`.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
