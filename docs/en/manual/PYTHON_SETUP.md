# Installing uv, Python and cocotb

`uv` and a Python for every user of the machine, with cocotb, the library the testbenches use, and `click`, which SymbiYosys imports. The install produces:

| Component | Role |
| :--- | :--- |
| `uv`, `uvx` | Python project manager, in `/usr/local/bin` |
| Python | The 3.14 series, installed by `uv` in `/opt/uv/python`, with `python3` and `python` in `/usr/local/bin` |
| cocotb | 2.1.0, installed in that Python |
| `click` | 8.5.0, installed in that Python |

## 1. Dependencies

### 1.1. Debian-like (`apt`)

The commands were run on Ubuntu 26.04.

```bash
sudo apt-get install -y ca-certificates curl git gcc g++
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
sudo dnf install -y ca-certificates git gcc gcc-c++
```

## 2. Build and install

Run the script as root (for example with `sudo -i`): it writes into `/opt` and, where noted, into `/usr/local/bin` and `/etc/profile.d`.

```bash
set -euo pipefail
UV_SERIES=0
PYTHON_SERIES=3.14
COCOTB_VERSION=2.1.0
CLICK_VERSION=8.5.0

# uv, from the installer of the latest release of the series, in /usr/local/bin
UV_VERSION=$(git ls-remote --tags --refs https://github.com/astral-sh/uv "$UV_SERIES.*" \
             | sed 's|.*refs/tags/||' | grep -E "^$UV_SERIES\.[0-9]+\.[0-9]+$" | sort -V | tail -n 1)
curl -fsSL "https://astral.sh/uv/$UV_VERSION/install.sh" -o /tmp/uv-install.sh
UV_UNMANAGED_INSTALL=/usr/local/bin sh /tmp/uv-install.sh
rm /tmp/uv-install.sh

# Python, in a directory every user reads, with cocotb and click installed in it
export UV_PYTHON_INSTALL_DIR=/opt/uv/python UV_PYTHON_PREFERENCE=only-managed
uv python install "$PYTHON_SERIES"
python=$(uv python find "$PYTHON_SERIES")
uv pip install --break-system-packages --python "$python" \
  "cocotb==$COCOTB_VERSION" "click==$CLICK_VERSION"
ln -sf "$python" /usr/local/bin/python3
ln -sf "$python" /usr/local/bin/python
chmod -R a+rX /opt/uv

# every user's shell finds that Python instead of downloading another
cat > /etc/profile.d/uv-python.sh <<'EOF'
export UV_PYTHON_INSTALL_DIR=/opt/uv/python
export UV_PYTHON_PREFERENCE=only-managed
EOF
```

- Python 3.14 is the version the projects require (`>=3.14,<3.15`), and cocotb 2.1.0 is the first release that supports it; cocotb is what fixes the Python version.
- The installer of the chosen `uv` version checks the binary against the SHA-256 it carries, and `UV_UNMANAGED_INSTALL` installs into `/usr/local/bin` without changing anyone's `PATH` or shell profile.
- `--break-system-packages` is needed because `uv` marks the Python it installs as externally managed.
- `/etc/profile.d/uv-python.sh` makes every shell find this Python, so a project's `uv sync` uses it instead of downloading another.

To update, run the script of section 2 again.

## 3. Verify

```bash
uv --version
python3 -c "import sys, cocotb, importlib.metadata as m; print('python', sys.version.split()[0], 'cocotb', cocotb.__version__, 'click', m.version('click'))"
```

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
