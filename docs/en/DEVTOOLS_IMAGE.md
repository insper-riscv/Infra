# Dev tools image

`ghcr.io/<organization>/dev_tools` is the development environment for a Dev Container: the [complete toolchain image](TOOLCHAIN_IMAGE.md) plus what one needs to work inside it, and the user `dev`. It is built from `Dockerfile.devtools` by the `Dev tools image` workflow and published for `linux/amd64`.

## 1. What it adds to the toolchain image

| Addition | Detail |
| :--- | :--- |
| GTKWave | the 4.0.0 development line (GTK 3 and 4), copied from the `infra-gtkwave` image into `/opt/gtkwave`; runs on Wayland natively and on X11 |
| User | `dev`, with `/work` as the working directory |
| Build tools | `build-essential`, `pkg-config`, `gnat` |
| Python | 3.14, installed for `dev` with `uv python install` |

GHDL, the RISC-V GCC with picolibc, Spike and `uv` come from the toolchain image. The image has no virtual environment and no `pip`: a Python project installs its dependencies with `uv sync`, and `uv` fetches the Python it needs.

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

GTKWave needs a display. On Wayland, pass the compositor socket and its name:

```bash
docker run --rm -it -v "$PWD:/work" \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR=/tmp -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  --user "$(id -u):$(id -g)" \
  ghcr.io/insper-riscv/dev_tools:latest gtkwave sim.ghw
```

On X11 (or Wayland through XWayland), mount the X socket and pass `DISPLAY` instead: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY`.

## 3. Publication

| Tag | Meaning |
| :--- | :--- |
| `latest` | the last publication |
| `sha-<Infra commit>` | the Infra commit that built it |

GTKWave is built by its own image, `infra-gtkwave` (Dockerfile.gtkwave, workflow `GTKWave image`), the same way as the GCC and Spike: a build stage compiles the commit, and the published image holds only the install directory. To update GTKWave, run the `GTKWave image` workflow by hand with the commit wanted (empty: the latest of the upstream default branch); the `Dev tools` image is then rebuilt.

The workflow runs when the `Toolchain image` or the `GTKWave image` workflow finishes, when `Dockerfile.devtools` changes on `main`, and on demand with the same confirmation secret as the other image workflows. It builds the image, checks that the user, GHDL, the GCC, GTKWave's libraries, `uv`, Python and a native compile all work, and only then publishes.

## 4. Limits

The image is `linux/amd64` only: on an ARM machine Docker runs it by emulation. The toolchain image it is built on has the same limit.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
