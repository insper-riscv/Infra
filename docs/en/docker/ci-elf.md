# ci-elf

`ghcr.io/<organization>/ci-elf` is level 3 of the CI images, with what the ELF tests need, that is the ACT4 suite (riscv-arch-test, the Architectural Certification Tests). It is [`ci-asm`](ci-asm.md), whose RISC-V GCC builds the ELFs, plus Sail ([`base-sail`](base-sail.md)), Ruby, Bundler and the dependencies of one ACT4 commit. [`dev_tools`](dev-tools.md) is built on it. The overview of the images is in [README.md](README.md).

## 1. What it adds to ci-asm

| Item | Detail | Version |
| :--- | :--- | :--- |
| Sail | `sail_riscv_sim`, in `/opt/riscv-foundation/sail`, from `base-sail` | the one in `base-sail` |
| Ruby and Bundler | ACT4 reads its configuration through the UDB gems | Ruby 3.3 from Ubuntu, Bundler 4.0.23 |
| Ruby gems of ACT4 (the UDB gems and their dependencies) | installed in `/opt/act-bundle` | the ones the commit in the label `act4.commit` records |
| Python packages of ACT4 | in the `uv` cache `/opt/act-uv-cache` | the ones that commit records |
| helper programs and the Z3 library that the UDB gems download | in `/opt/act-cache` | the ones the gems ask for |

The three cache directories can be written by any user of the container.

## 2. Running the ACT4 suite

Clone ACT4 at the commit your project pins, then run the container with the clone as the working directory:

```bash
docker run --rm -it --user "$(id -u):$(id -g)" -e HOME=/tmp -e UV_LINK_MODE=copy \
  -v "$PWD:/work" -w /work ghcr.io/insper-riscv/ci-elf:latest bash
```

Inside the container, the suite is generated, compiled and run as in the ACT4 documentation. The compiler of the image is `riscv32-unknown-elf-gcc`, so the configuration of the DUT names it:

```yaml
compiler_exe: riscv32-unknown-elf-gcc
objdump_exe: riscv32-unknown-elf-objdump
ref_model_exe: sail_riscv_sim
```

Then, in the ACT4 directory:

```bash
CONFIG_FILES=<directory of the DUT>/test_config.yaml make EXTENSIONS=I,M
```

With the configuration `config/sail/sail-rv32-max` of ACT4 and only those two compiler names changed, the suite for the extension I generates its ELFs and Sail runs all of them.

`--user` makes the files that ACT4 creates belong to you, `HOME=/tmp` gives tools that want a home directory one that any user can write, and `UV_LINK_MODE=copy` avoids a warning when the `uv` cache and the working directory are on different file systems. On a Docker daemon that remaps user namespaces, add `--userns=host`.

## 3. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/ci/elf/Dockerfile` |
| Workflow | `ELF image` |
| Tags | `latest`, `sha-<Infra commit>` and `asm-<12 of the ci-asm digest>-sail-<7 of the Sail commit>-act4-<7 of the ACT4 commit>` |
| Labels | `act4.commit` and `sail-riscv.commit` |
| Schedule | when `ASM image` or `Sail image` finishes |

The ACT4 commit whose dependencies are installed is the `ACT4_COMMIT` of the `ELF image` workflow, which changes by editing it, or by the `act4_commit` field of a manual run. The projects that use ACT4 pin it as a submodule, and the two commits must move together.

| Manual run field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `act4_commit` | the `riscv/riscv-arch-test` commit; empty, the `ACT4_COMMIT` of the workflow |

## 4. Building locally

```bash
docker build -f docker/ci/elf/Dockerfile -t ci-elf \
  --build-arg ASM_IMAGE=ci-asm --build-arg SAIL_IMAGE=base-sail \
  --build-arg ACT4_COMMIT=<commit of riscv/riscv-arch-test> .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `ASM_IMAGE` | `ci-asm:latest` | the level below |
| `SAIL_IMAGE` | `base-sail:latest` | where Sail comes from |
| `ACT4_COMMIT` | none | the `riscv/riscv-arch-test` commit whose dependencies go in |
| `BUNDLER_VERSION` | `4.0.23` | the Bundler the `Gemfile.lock` of ACT4 records |

The build ends by checking `ruby --version`, `bundle --version` and `sail_riscv_sim --version`, and that Sail has no missing library.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
