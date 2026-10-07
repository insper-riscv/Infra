# Dev tools image

`ghcr.io/<organization>/dev_tools` is the development environment for a Dev Container: the [complete toolchain image](TOOLCHAIN_IMAGE.md) plus what one needs to work inside it, and the user `dev`. It is built from `Dockerfile.devtools` by the `Dev tools image` workflow and published for `linux/amd64` and `linux/arm64`.

## 1. What it adds to the toolchain image

| Addition | Detail |
| :--- | :--- |
| GTKWave | the stable 3.3 line (3.3.116, GTK 3 tree), copied from the `infra-gtkwave` image into `/opt/gtkwave`; runs on Wayland natively and on X11 |
| User | `dev`, with `/work` as the working directory |
| Build tools | `build-essential`, `pkg-config`, `gnat` |

GHDL, the RISC-V GCC with picolibc, Spike, `uv`, Python 3.14 and cocotb 2.1.0 come from the toolchain image, which explains why Python is pinned to 3.14 (cocotb fixes it). The image has no `pip`: a Python project installs its other dependencies with `uv sync`, which finds that Python.

## 2. Using it

Interactively, with the current directory mounted:

```bash
docker run --rm -it -v "$PWD:/work" ghcr.io/insper-riscv/dev_tools:latest
```

In a `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/insper-riscv/dev_tools:latest",
  "remoteUser": "dev",
  "workspaceFolder": "/work",
  "workspaceMount": "source=${localWorkspaceFolder},target=/work,type=bind,consistency=cached"
}
```

### 2.1 Opening GTKWave

GTKWave is the GTK 3 tree of the stable 3.3 line, which has a Wayland backend. `twinwave` and the `-X` option embed windows with XEmbed, which exists only on X11, and do not work on Wayland; opening a waveform file does not use either.

GTKWave needs a display. On Wayland, pass the compositor socket and its name:

```bash
docker run --rm -it -v "$PWD:/work" \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR=/tmp -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  --user "$(id -u):$(id -g)" \
  ghcr.io/insper-riscv/dev_tools:latest gtkwave sim.ghw
```

On an X11 session, where there is no Wayland socket, mount the X socket and pass `DISPLAY` instead: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY`. To force one backend, set `GDK_BACKEND=wayland` or `GDK_BACKEND=x11`.

## 3. Publication

| Tag | Meaning |
| :--- | :--- |
| `latest` | the last publication |
| `sha-<Infra commit>` | the Infra commit that built it |

GTKWave is built by its own image, `infra-gtkwave` (Dockerfile.gtkwave, workflow `GTKWave image`), the same way as the GCC and Spike: a build stage compiles the commit, and the published image holds only the install directory. To update GTKWave, run the `GTKWave image` workflow by hand with the commit wanted (empty: the latest of the upstream default branch); the `Dev tools` image is then rebuilt.

The workflow runs when the `Toolchain image` or the `GTKWave image` workflow finishes, when `Dockerfile.devtools` changes on `main`, and on demand with the same confirmation secret as the other image workflows. Like `Toolchain image`, it does not fail when an input is missing and does not assemble twice. If the `infra-gtkwave` or `infra-toolchain` image is not published yet, it ends with a notice and runs when they finish. If a `GTKWave image` or `Toolchain image` run is queued or going, it skips with a notice, and the end of that run triggers it again, so the last one to finish does the single assembly. When a run is triggered for a combination of commits that already has an image (tag `ghdl-<7>-gcc-<7>-spike-<7>-gtkwave-<7>-toolchain-<12>`, which ends with the start of the digest of the toolchain image, since the toolchain can change while the commits of the components stay the same), it builds nothing. A manual run never defers, and fails with a message when the inputs do not exist.

It builds the image, checks that the user, GHDL, the GCC, GTKWave's libraries, `uv`, Python and a native compile all work, and only then publishes.

## 4. Architectures

The image is published for `linux/amd64` and `linux/arm64` (an Intel or AMD PC, and an ARM machine such as a Mac), with the same versions of the same tools on both: GHDL has the LLVM backend, and the GCC, Spike and GTKWave are built from the same commits.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
