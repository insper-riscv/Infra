# Dev tools image

`ghcr.io/<organization>/dev_tools` is the development environment for a Dev Container: the [complete toolchain image](TOOLCHAIN_IMAGE.md) plus what one needs to work inside it, and the user `dev`. It is built from `Dockerfile.devtools` by the `Dev tools image` workflow and published for `linux/amd64`.

## 1. What it adds to the toolchain image

| Addition | Detail |
| :--- | :--- |
| User | `dev`, with `/work` as the working directory |
| Build tools | `build-essential`, `pkg-config`, `gnat` |
| Synthesis and waveforms | `yosys`, `gtkwave` |

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

## 3. Publication

| Tag | Meaning |
| :--- | :--- |
| `latest` | the last publication |
| `sha-<Infra commit>` | the Infra commit that built it |

The workflow runs when the `Toolchain image` workflow finishes, when `Dockerfile.devtools` changes on `main`, and on demand with the same confirmation secret as the other image workflows. It builds the image, checks that the user, GHDL, the GCC, `yosys`, `gtkwave`, `uv` and a native compile all work, and only then publishes.

## 4. Limits

The image is `linux/amd64` only: on an ARM machine Docker runs it by emulation. The toolchain image it is built on has the same limit.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
