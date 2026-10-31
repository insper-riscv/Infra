# Docker images: overview

The project's Docker images hold what the RISC-V test flow needs. There are three kinds.

| Kind | Name | What it is |
| :--- | :--- | :--- |
| Base | `base-*` | one tool per image (GHDL, Yosys with SymbiYosys, the GCC, picolibc, Spike, Sail, GTKWave) and nothing else; they exist to be copied from |
| CI | `ci-*` | the images a project's CI runs in; each is the one before it plus more tools, in levels |
| Final | `dev_tools` | the last level, for the Dev Container |

The `Dockerfile`s are in the `docker` folder of this repository (`base/`, `ci/` and `dev-tools/`), and one workflow per image publishes them to the GitHub Container Registry, under `ghcr.io/<organization>/`. Every image is published for `linux/amd64` and `linux/arm64`, with the same versions of the same tools; GHDL has the LLVM backend on both, so a simulation behaves the same on a PC and on an ARM machine such as a Mac.

## 1. The levels

```text
base-ghdl    base-yosys    uv
     └───────────┴──────────┘
                 ▼
            ci-vhdl            GHDL, Yosys, uv, Python, cocotb, static analysis, riscv-tools
                 │
                 │      base-gcc → base-picolibc      base-spike
                 │              └────────┬─────────────────┘
                 ▼                       ▼
            ci-elf   = ci-vhdl + GCC with picolibc + Spike
                 │
                 │      base-sail
                 │          │
                 ▼          ▼
            ci-act4   = ci-elf + Sail + ACT4 dependencies
                 │
                 │      base-gtkwave
                 │          │
                 ▼          ▼
            dev_tools = ci-act4 + GTKWave + user dev
```

| Level | Image | For | Adds to the level before |
| :--- | :--- | :--- | :--- |
| 1 | [`ci-vhdl`](ci-vhdl.md) | VHDL tests (cocotb, formal proofs) | GHDL, Yosys with SymbiYosys, `uv`, Python 3.14, cocotb, static analysis tools, `riscv-tools` |
| 2 | [`ci-elf`](ci-elf.md) | building ELFs (compiling assembly and C) and running them on Spike | the RISC-V GCC with picolibc, Spike |
| 3 | [`ci-act4`](ci-act4.md) | ACT4 certification | Sail, Ruby, Bundler, the dependencies of one ACT4 commit |
| 4 | [`dev_tools`](dev-tools.md) | Dev Container | GTKWave, the user `dev` |

A level contains every level below it, so a CI job takes the lowest level that has what it needs.

The base images, one per tool:

| Image | Holds | File |
| :--- | :--- | :--- |
| `base-ghdl` | `/opt/ghdl` | [base-ghdl.md](base-ghdl.md) |
| `base-yosys` | `/opt/yosys` (Yosys and SymbiYosys) | [base-yosys.md](base-yosys.md) |
| `base-gcc` | `/opt/riscv-foundation/riscv32-elf` (binutils, the GCC and libgcc) | [base-gcc.md](base-gcc.md) |
| `base-picolibc` | the files picolibc installs into the GCC's sysroot | [base-picolibc.md](base-picolibc.md) |
| `base-spike` | `/opt/riscv-foundation/spike` | [base-spike.md](base-spike.md) |
| `base-sail` | `/opt/riscv-foundation/sail` | [base-sail.md](base-sail.md) |
| `base-gtkwave` | `/opt/gtkwave` | [base-gtkwave.md](base-gtkwave.md) |

A base image has no file system besides its install directory, so it cannot be run.

## 2. Tags and labels

| Image | Tags |
| :--- | :--- |
| `base-*` | the commit (or version) of the tool, and `latest`; the exact format is in each image's file |
| `ci-*` and `dev_tools` | `latest`, `sha-<Infra commit>` and a combination tag that names everything in the image |

The combination tag of a level names the start of the digest of the image below it and the commits of the components it adds. Any change at any lower level therefore makes a new combination.

Every image carries the labels `org.opencontainers.image.title`, `description`, `source`, `revision` (the commit of this repository that built it) and `created`, set by the workflow, and the commit labels of its components (`ghdl.commit`, `riscv-gnu-toolchain.commit`, `picolibc.commit`, `riscv-isa-sim.commit`, `yosys.commit`, `sby.commit`, `sail-riscv.commit`, `gtkwave.commit`, `act4.commit`, `uv.version`). The labels are set explicitly because an image built on the Ubuntu base would otherwise inherit the title, the description and the date of the Ubuntu image.

## 3. Using the CI images

Pick the level that has the tools the job needs. Interactively, with the current directory mounted:

```bash
docker run --rm -it -v "$PWD:/workspace" ghcr.io/insper-riscv/ci-elf:latest
```

In a GitHub Actions job:

```yaml
jobs:
  sim:
    runs-on: ubuntu-26.04
    container:
      image: ghcr.io/insper-riscv/ci-elf:latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: riscv32-unknown-elf-gcc --version
```

For a reproducible result, use the `sha-<commit>` tag of the wanted publication instead of `latest`.

## 4. Automatic updates

Each base image has a workflow that runs every day (UTC) with no field to fill in. The four assembled images (`ci-vhdl`, `ci-elf`, `ci-act4` and `dev_tools`) are built by one workflow, `CI images`, whose jobs run one after the other, from level 1 to level 4. It runs every day, which also looks up `uv` (it has no base image) and picks up the latest GTKWave, and when a base image it uses finishes. A base image that finds nothing new still finishes successfully, so the workflow runs every day after the bases.

| Workflow | When | What it looks at |
| :--- | :--- | :--- |
| `GHDL image` | every day, 03:00 | the latest `6.x.y` release |
| `Picolibc image` | every day, 03:10, and when `GCC image` finishes | the latest `1.x.y` release, compiled with the latest GCC |
| `Yosys image` | every day, 03:00 | the latest `v0.N` release of Yosys, with the `sby` of the same version |
| `GTKWave image` | every day, 03:00 | the head of the `lts` branch |
| `Spike image` | every day, 03:00 | the latest upstream commit with green CI (it can wait up to 60 minutes for a running one) |
| `GCC image` | every day, 03:00 | the latest commit of `riscv-gnu-toolchain` whose `Build` succeeded |
| `Sail image` | every day, 03:00 | the latest commit of the Sail `master` whose upstream `ci.yml` passed |
| `CI images` | every day, 03:00, and when `GHDL image`, `Yosys image`, `GCC image`, `Picolibc image`, `Spike image` or `Sail image` finishes | the latest `uv` of series 0, the six bases above, GTKWave, and the image of the level below at each level |

A run builds **only if the image for that version does not exist yet**; when nothing changed it ends in seconds with a notice.

The rules that hold for the assembled images (`ci-*` and `dev_tools`), which `CI images` applies at each level:

1. It reads the commits in the labels of the components it copies, and, at each level, the digest of the image of the level below (the one just built in the run, or the one published for the combination).
2. If any component is not published yet, it ends with a notice, without failing, and runs when they finish. A manual run without them fails, with a message that points at the workflows to run first.
3. If a workflow it depends on is queued or going, it skips with a notice, and the end of that run triggers it again; the last one to finish does the single assembly. A manual run never defers.
4. Each level publishes only for a combination that does not exist yet. A level that is skipped for that reason does not stop the next one, because the image below it may have changed; a level that fails stops the ones above it.

**A change of a `Dockerfile` or of a workflow builds nothing.** An image is built when a version changes, not when its recipe changes, so a recipe change that is not a new version does not rebuild, for nothing, images that take up to an hour. When a recipe changes on `main`, the `Recipe changed` workflow lists the affected images, and rebuilding is a manual run (`force` in a component, `from_level` in `CI images`).

Each architecture is built on a runner of its own (`ubuntu-26.04` for `linux/amd64` and `ubuntu-24.04-arm` for `linux/arm64`), because the GCC and GHDL builds take hours under emulation. A final job joins the two images into one manifest with the tags, so `docker pull` gives each machine its own.

### 4.1. Manual runs

Every image workflow can be started in **Actions → Run workflow**. The `confirm` field is required (see section 5). The components also have `commit` (empty: the latest) and `force` (rebuild and republish even if the image for that commit exists). `CI images` has `from_level` instead of `force`: it rebuilds that level and the ones above it, whatever is published; the other fields are in the file of each image.

## 5. Publishing and security

The image workflows publish to `ghcr.io/<organization>/`, with the run's own `GITHUB_TOKEN`. The visibility of each package (public or private) is set in the package's settings on GitHub, not by the workflow. All the packages must be reachable by whoever will use them, and `Toolchain image` reads the component packages.

The manual run of any of the image workflows asks for the `confirm` field, which must equal the value of the `IMAGE_PUBLISH_SECRET` secret. It is the same second gate described in section 9 of [RUNNER_SETUP.md](../RUNNER_SETUP.md): write access to the repository already controls who can trigger the workflow, and the secret makes sure only someone who knows it publishes the image. The assembling workflows also run after what they build on finishes. A run that a schedule or another workflow starts does not ask for `confirm`: the gate for a push is branch protection, and a component's run already went through its own `confirm` or its push.

To set it up, in the repository: **Settings → Secrets and variables → Actions → New repository secret**, named `IMAGE_PUBLISH_SECRET`, with any phrase as the value (for example `openssl rand -hex 32`).

## 6. Cleaning old versions

Every publication adds versions to the package and none is removed by a workflow of ours. `scripts/cleanup-images.sh` deletes the old ones and keeps what the tag `latest` reaches: the manifest tagged `latest` and every manifest below it (the image of each architecture and its attestation). Those manifests have no tag of their own and are what keeps `latest` pullable, so a plain "delete the untagged versions" would break it. Everything else is deleted, tagged or not, including the tags of earlier commits.

```bash
scripts/cleanup-images.sh                        # every package, only listing
scripts/cleanup-images.sh base-gcc dev_tools    # only these, only listing
scripts/cleanup-images.sh --delete base-gcc     # really deletes
```

| Safeguard | What it does |
| :--- | :--- |
| Listing first | it deletes only with `--delete` (the workflow: the `delete` field, off by default) |
| Minimum age | a version younger than `MIN_AGE_MINUTES` (120 by default) is never deleted, because a publication pushes the image of each architecture without a tag and tags the manifest above them only at the end |
| No `latest` | a package with no version tagged `latest`, or whose manifest cannot be read, is left untouched |
| Missing manifest | a manifest that `latest` references and that is no longer in the registry is reported as a warning and does not stop the run |

The workflow `Clean up old image versions` runs it by hand, with the same `confirm` field as the publications. With `delete` on it also refuses to run while any image workflow is queued or running.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
