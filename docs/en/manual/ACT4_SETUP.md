# Installing the ACT4 environment

The dependencies to run the ACT4 suite (riscv-arch-test, the Architectural Certification Tests): Ruby, Bundler, the Ruby gems of the UDB and the Python packages of one ACT4 commit. The RISC-V GCC ([GCC_SETUP.md](GCC_SETUP.md)), `uv` and Python ([PYTHON_SETUP.md](PYTHON_SETUP.md)) and Sail ([SAIL_SETUP.md](SAIL_SETUP.md)) are installed before. The install produces:

| Component | Role |
| :--- | :--- |
| Ruby and Bundler | Ruby 3.3 from the distro and Bundler 4.0.23, the version the `Gemfile.lock` of ACT4 records; the `Gemfile` accepts Ruby `~> 3.2` |
| `/opt/act-bundle` | The Ruby gems of ACT4 (the UDB gems and their dependencies) |
| `/opt/act-uv-cache` | The Python packages of that commit, in the cache of `uv` |
| `/opt/act-cache` | The helper programs and the Z3 library that the UDB gems download when they are installed |

## 1. Dependencies

### 1.1. Debian-like (`apt`)

The commands were run on Ubuntu 26.04.

```bash
sudo apt-get install -y build-essential git ca-certificates ruby ruby-dev libyaml-dev \
  libffi-dev zlib1g-dev libssl-dev libz3-dev
```

### 1.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are equivalent. The commands were run on Rocky Linux 9.

Some packages are in the `crb` and EPEL repositories; enable them first:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

On RHEL itself, `epel-release` is not in the base repositories: enable EPEL as described in its [documentation](https://docs.fedoraproject.org/en-US/epel/).

Rocky Linux 9 ships Ruby 3.0 and the `Gemfile` of ACT4 accepts Ruby `~> 3.2`, so the Ruby 3.3 module is enabled before the packages.

```bash
sudo dnf module enable -y ruby:3.3
sudo dnf install -y gcc gcc-c++ make git ca-certificates ruby ruby-devel libyaml-devel \
  libffi-devel zlib-devel openssl-devel z3-devel
```

## 2. Build and install

Run the script as root (for example with `sudo -i`): it writes into `/opt` and, where noted, into `/usr/local/bin` and `/etc/profile.d`.

```bash
set -euo pipefail
ACT4_COMMIT=<commit of riscv/riscv-arch-test that the project pins>
BUNDLER_VERSION=4.0.23

gem install --no-document bundler -v "$BUNDLER_VERSION"

# fixed directories that any user can write, so a project's own checkout of ACT4 finds the
# gems and the Python packages and can still add what its commit needs
cat > /etc/profile.d/act4.sh <<'EOF'
export BUNDLE_PATH=/opt/act-bundle
export UV_CACHE_DIR=/opt/act-uv-cache
export XDG_CACHE_HOME=/opt/act-cache
EOF
. /etc/profile.d/act4.sh
mkdir -p "$BUNDLE_PATH" "$UV_CACHE_DIR" "$XDG_CACHE_HOME"

BUILD_DIR=$(mktemp -d -p /var/tmp act4-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
git init "$BUILD_DIR/act4"
git -C "$BUILD_DIR/act4" fetch --depth 1 https://github.com/riscv/riscv-arch-test "$ACT4_COMMIT"
git -C "$BUILD_DIR/act4" checkout FETCH_HEAD

(cd "$BUILD_DIR/act4/framework/src/act/data" && bundle install --jobs 4)
(cd "$BUILD_DIR/act4" && uv sync --frozen --all-packages)

chmod -R a+rwX "$BUNDLE_PATH" "$UV_CACHE_DIR" "$XDG_CACHE_HOME"
```

- Set `ACT4_COMMIT` to the commit of `riscv/riscv-arch-test` that the project pins, so the dependencies installed are the ones that commit records.
- `/etc/profile.d/act4.sh` points `BUNDLE_PATH`, `UV_CACHE_DIR` and `XDG_CACHE_HOME` at the three directories, in every shell; the directories are writable by any user, so a project's own checkout of ACT4 finds what was installed and can still add what its commit needs.

To update, run the script of section 2 again.

## 3. Verify

```bash
ruby --version
bundle --version
sail_riscv_sim --version
```

Then, in the ACT4 directory, the suite is generated, compiled and run as in the ACT4 documentation. The compiler of the install is `riscv32-unknown-elf-gcc`, so the configuration of the DUT names it:

```yaml
compiler_exe: riscv32-unknown-elf-gcc
objdump_exe: riscv32-unknown-elf-objdump
ref_model_exe: sail_riscv_sim
```

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
