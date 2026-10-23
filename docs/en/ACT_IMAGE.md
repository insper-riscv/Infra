# ACT images

`ghcr.io/<organization>/act_tools` is the environment to run the ACT4 suite (riscv-arch-test, the Architectural Certification Tests): the [dev tools image](DEVTOOLS_IMAGE.md) plus Sail, Ruby, Bundler and the dependencies of one commit of ACT4. `ghcr.io/<organization>/infra-sail` holds Sail alone, and `act_tools` copies it from there. Both are published for `linux/amd64` and `linux/arm64`.

## 1. What the images hold

| Image | Item | Version |
| :--- | :--- | :--- |
| `infra-sail` | `sail_riscv_sim`, the executable of the Sail RISC-V model, in `/opt/sail` | the latest stable release of the series 0 (a release is named `0.N`) |
| `act_tools` | everything in `dev_tools` | see the dev tools image |
| `act_tools` | Sail | the one in `infra-sail` |
| `act_tools` | Ruby and Bundler | Ruby 3.3 from Ubuntu, Bundler 4.0.23 |
| `act_tools` | Ruby gems of ACT4 (the UDB gems and their dependencies), installed in `/opt/act-bundle` | the ones the commit in the label `act4.commit` records |
| `act_tools` | Python packages of ACT4, in the `uv` cache `/opt/act-uv-cache` | the ones that commit records |
| `act_tools` | helper programs and the Z3 library that the UDB gems download, in `/opt/act-cache` | the ones the gems ask for |

The three directories of `act_tools` can be written by any user of the container.

## 2. Running the ACT4 suite

Clone ACT4 at the commit your project pins, then run the container with the clone as the working directory:

```bash
docker run --rm -it --user "$(id -u):$(id -g)" -e HOME=/tmp -e UV_LINK_MODE=copy \
  -v "$PWD:/work" -w /work ghcr.io/insper-riscv/act_tools:latest bash
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

## 3. Without network

With the ACT4 commit of the label `act4.commit`, `make tests` and `make` need no network: the gems, the Python packages and the helper programs are in the image. A different ACT4 commit that changes a dependency needs the network the first time it runs, and the downloads go to the same directories.

## 4. Publication

| Image | Tags |
| :--- | :--- |
| `infra-sail` | the commit of the release tag, and `latest` |
| `act_tools` | `latest`, `sha-<Infra commit>`, and `devtools-<12 digits of the dev tools digest>-sail-<7 of the Sail commit>-act4-<7 of the ACT4 commit>` |

The `Sail image` workflow runs every day at 03:10 UTC, takes the latest stable release of the series 0 and builds it if the image for its commit does not exist. It checks each tarball against the SHA-256 that GitHub publishes for the asset. The `ACT image` workflow runs every day at 04:30 UTC and when the Dev tools image or the Sail image workflow finishes; it builds when the combination in the tag does not exist.

The commit of ACT4 whose dependencies are installed is the `ACT4_COMMIT` of the `ACT image` workflow, which changes by editing it, or by the `act4_commit` field of a manual run. A manual run of either workflow with `confirm` set to the value of the secret `IMAGE_PUBLISH_SECRET` rebuilds the image.

Local build:

```bash
docker build -f Dockerfile.sail -t infra-sail \
  --build-arg SAIL_VERSION=0.16 \
  --build-arg SAIL_SHA256_AMD64=<digest of sail-riscv-Linux-x86_64.tar.gz> \
  --build-arg SAIL_SHA256_ARM64=<digest of sail-riscv-Linux-aarch64.tar.gz> .

docker build -f Dockerfile.act -t act_tools \
  --build-arg SAIL_IMAGE=infra-sail \
  --build-arg ACT4_COMMIT=<commit of riscv/riscv-arch-test> .
```
