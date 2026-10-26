# dev_tools

`ghcr.io/<organization>/dev_tools` is the development environment for a Dev Container, and the last level of the images. It is [`ci-elf`](ci-elf.md) (and so the VHDL, assembly and ELF levels) plus what one needs to work inside it, and the user `dev`. The overview of the images is in [README.md](README.md). It is built from `docker/dev-tools/Dockerfile` by the `CI images` workflow and published for `linux/amd64` and `linux/arm64`.

## 1. What it adds to `ci-elf`

| Addition | Detail |
| :--- | :--- |
| GTKWave | the head of the `lts` branch (3.3 maintenance line, GTK 3 tree), copied from the `base-gtkwave` image into `/opt/gtkwave`; runs on Wayland natively and on X11 |
| User | `dev`, with `/work` as the working directory |
| Build tools | `build-essential`, `pkg-config`, `gnat` |

GHDL, Yosys, the RISC-V GCC with picolibc, Spike, Sail, the ACT4 dependencies, `uv`, Python 3.14 and cocotb 2.1.0 come from `ci-elf`, which explains why Python is pinned to 3.14 (cocotb fixes it). The image has no `pip`: a Python project installs its other dependencies with `uv sync`, which finds that Python.

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

GTKWave is the GTK 3 tree of the 3.3 maintenance line, which has a Wayland backend. `twinwave` and the `-X` option embed windows with XEmbed, which exists only on X11, and do not work on Wayland; opening a waveform file does not use either.

GTKWave needs a display. On Wayland, pass the compositor socket and its name:

```bash
docker run --rm -it -v "$PWD:/work" \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR=/tmp -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  --user "$(id -u):$(id -g)" \
  ghcr.io/insper-riscv/dev_tools:latest gtkwave sim.ghw
```

On an X11 session, where there is no Wayland socket, mount the X socket and pass `DISPLAY` instead: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY`. To force one backend, set `GDK_BACKEND=wayland` or `GDK_BACKEND=x11`.

On a Docker daemon that remaps user namespaces (`userns-remap`), the host user appears as `nobody` inside the container and cannot use the socket or the mounted directory: add `--userns=host` to the command.

## 3. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/dev-tools/Dockerfile` |
| Workflow | `CI images`, job `devtools` |
| Tags | `latest`, `sha-<Infra commit>` and `elf-<12 of the ci-elf digest>-gtkwave-<7>` |
| Label | `gtkwave.commit` |
| Schedule | in the same run as `ci-elf`, right after it; a new GTKWave is picked up by the run of 03:00 UTC |

The image is assembled from the latest `ci-elf` and the latest `base-gtkwave`, so a new version of either makes a new image. The long tag names the digest of `ci-elf` because any level below it can change while the GTKWave commit stays the same, and a combination that already has an image is not built again. The rules that every assembled image follows, such as waiting for what it copies and for a workflow that is going, are in section 4 of the [overview of the images](README.md).

GTKWave comes from [`base-gtkwave`](base-gtkwave.md); a run of the `GTKWave image` workflow does not start `CI images`, and `dev_tools` takes the new GTKWave in the next run of `CI images`, at 03:00 UTC or by hand with `from_level` set to `devtools`.

Before publishing, the workflow checks that the image runs as the user `dev` in `/work`, that GHDL, Sail, Ruby, the RISC-V GCC, `uv`, Python with cocotb and a native compile all work, and that GTKWave has all its libraries.

## 4. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `from_level` | the level to rebuild from (`vhdl`, `asm`, `elf` or `devtools`): it and the ones above it are rebuilt, the ones below are reused |

## 5. Building locally

```bash
docker build -f docker/dev-tools/Dockerfile -t dev_tools \
  --build-arg ELF_IMAGE=ci-elf --build-arg GTKWAVE_IMAGE=base-gtkwave .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `ELF_IMAGE` | `ci-elf:latest` | the level below |
| `GTKWAVE_IMAGE` | `base-gtkwave:latest` | where GTKWave comes from |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
