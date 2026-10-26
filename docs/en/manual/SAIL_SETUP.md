# Installing Sail

The Sail RISC-V model (`sail_riscv_sim`), from the tarball of the latest stable `0.N` release of `riscv/sail-riscv`, installed in `/opt/riscv-foundation/sail`. The weekly pre-releases of the repository are not stable releases and are not taken. The install produces:

| Component | Role |
| :--- | :--- |
| `sail_riscv_sim` | The executable of the model: runs a RISC-V program and computes the expected result of each test |
| `include`, `share` | The headers and data files the tarball of the release brings |

## 1. Dependencies

### 1.1. Debian-like (`apt`)

The commands were run on Ubuntu 26.04.

```bash
sudo apt-get install -y ca-certificates curl git jq
```

### 1.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are equivalent. The commands were run on Rocky Linux 9.

Some packages are in the `crb` and EPEL repositories; enable them first:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

On RHEL itself, `epel-release` is not in the base repositories: enable EPEL as described in its [documentation](https://docs.fedoraproject.org/en-US/epel/).

The `curl` command is already provided by `curl-minimal`, which Rocky installs, and the `curl` package conflicts with it, so `curl` is not in the list.

```bash
sudo dnf install -y ca-certificates git jq
```

## 2. Build and install

Run the script as root (for example with `sudo -i`): it writes into `/opt` and, where noted, into `/usr/local/bin` and `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/riscv-foundation/sail
VERSION=$(git ls-remote --tags --refs https://github.com/riscv/sail-riscv | sed 's|.*refs/tags/||' \
          | grep -E '^0\.[0-9]+$' | sort -V | tail -n 1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$VERSION" ]; then
  echo "Sail is already at $VERSION, nothing to do"
  exit 0
fi

case "$(uname -m)" in
  x86_64)  asset=sail-riscv-Linux-x86_64.tar.gz ;;
  aarch64) asset=sail-riscv-Linux-aarch64.tar.gz ;;
  *) echo "no Sail release for $(uname -m)"; exit 1 ;;
esac

# GitHub publishes the SHA-256 of each asset of a release
sum=$(curl -fsSL "https://api.github.com/repos/riscv/sail-riscv/releases/tags/$VERSION" \
      | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .digest')
curl -fsSL -o /tmp/sail.tar.gz "https://github.com/riscv/sail-riscv/releases/download/$VERSION/$asset"
echo "${sum#sha256:}  /tmp/sail.tar.gz" | sha256sum -c -

rm -rf "$PREFIX" && mkdir -p "$PREFIX"
tar -xzf /tmp/sail.tar.gz -C "$PREFIX" --strip-components=1
rm /tmp/sail.tar.gz
echo "$VERSION" > "$PREFIX/.tag"
```

- The release names its tarballs by the architecture of the machine (`x86_64`, `aarch64`), and GitHub publishes the SHA-256 of each asset, which the script checks before extracting.
- The build runs in `/var/tmp`, not in `/tmp`, which is often a tmpfs too small for the build tree, and the directory is deleted at the end.
- `.tag` is written last: an interrupted build leaves the install without `.tag`, so the next run rebuilds instead of trusting an incomplete install, and a run at the version already installed does nothing.

To update, run the script of section 2 again.

## 3. Verify

```bash
/opt/riscv-foundation/sail/bin/sail_riscv_sim --version
ldd /opt/riscv-foundation/sail/bin/sail_riscv_sim | grep "not found" || echo "no missing library"
```

## 4. Global PATH

Adds the binaries to the global `PATH`, by creating a wrapper for each one in `/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/sail/bin/*; do
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
