# Building Yosys and SymbiYosys

Yosys and SymbiYosys (`sby`), built from source from the latest `v0.N` release of each repository, which are released in step, and installed in `/opt/yosys`. They prove properties of the Verilog netlist that GHDL synthesizes from the VHDL. The build produces:

| Component | Role |
| :--- | :--- |
| `yosys` | The synthesis and formal verification framework |
| `yosys-abc` | The logic optimizer Yosys calls |
| `yosys-smtbmc` | Runs the bounded model check and the induction that `sby` asks of the SMT solver |
| `yosys-witness` | Converts and inspects the witness traces of a proof |
| `yosys-config` | Prints the flags to build Yosys plug-ins |
| `yosys-filterlib` | Filters Liberty cell libraries |
| `sby` | SymbiYosys: runs Yosys and the solvers (`z3`, `boolector`) to prove properties of a block |

## 1. Dependencies

### 1.1. Debian-like (`apt`)

The commands were run on Ubuntu 26.04.

```bash
sudo apt-get install -y build-essential cmake git ca-certificates python3 pkg-config gawk \
  bison flex libreadline-dev libffi-dev libfl-dev tcl-dev zlib1g-dev python3-click z3 boolector
```

### 1.2. RHEL-like (`dnf`/`yum`)

On RHEL 8 or newer, `yum` is an alias for `dnf`; the two commands are equivalent. The commands were run on Rocky Linux 9.

Some packages are in the `crb` and EPEL repositories; enable them first:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

On RHEL itself, `epel-release` is not in the base repositories: enable EPEL as described in its [documentation](https://docs.fedoraproject.org/en-US/epel/).

`boolector` has no package in these repositories. The proof of this guide uses `z3`, and the `boolector` engine of `sby` only runs if `boolector` is installed by other means.

```bash
sudo dnf install -y gcc gcc-c++ make cmake git ca-certificates python3 pkgconf-pkg-config \
  gawk bison flex flex-devel readline-devel libffi-devel tcl-devel zlib-devel python3-click z3
```

## 2. Build and install

Run the script as root (for example with `sudo -i`): it writes into `/opt` and, where noted, into `/usr/local/bin` and `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/yosys
TAG=$(git ls-remote --tags --refs https://github.com/YosysHQ/yosys 'v0.*' | sed 's|.*refs/tags/||' \
      | grep -E '^v0\.[0-9]+$' | sort -V | tail -n 1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$TAG" ]; then
  echo "Yosys is already at $TAG, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp yosys-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
rm -rf "$PREFIX"

# Yosys, without the Slang front end
git clone --depth 1 --branch "$TAG" https://github.com/YosysHQ/yosys "$BUILD_DIR/yosys"
git -C "$BUILD_DIR/yosys" submodule update --init --depth 1 \
  abc libs/symfpu libs/cxxopts libs/fmt libs/tomlplusplus
cd "$BUILD_DIR/yosys"
cmake -B build . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DYOSYS_USE_BUNDLED_LIBS=ON -DYOSYS_WITHOUT_SLANG=ON -DYOSYS_ENABLE_UNIT_TESTS=OFF
cmake --build build --parallel "$(nproc)"
cmake --install build --strip

# SymbiYosys, the release with the same version
git clone --depth 1 --branch "$TAG" https://github.com/YosysHQ/sby "$BUILD_DIR/sby"
make -C "$BUILD_DIR/sby" install PREFIX="$PREFIX" YOSYS_RELEASE_VERSION="SBY $TAG"

echo "$TAG" > "$PREFIX/.tag"
```

- `-DYOSYS_WITHOUT_SLANG=ON` leaves out the SystemVerilog front end based on Slang, the largest part of the build; the properties are read with the built-in `read_verilog -formal -sv`.
- `-DYOSYS_USE_BUNDLED_LIBS=ON` uses the libraries Yosys carries as submodules (`cxxopts`, `fmt`, `tomlplusplus`), and `abc` and `symfpu` are the other submodules a build without Slang needs.
- `sby` is Python and installs next to Yosys; `python3-click` is the library it imports, and `YOSYS_RELEASE_VERSION` gives it the version string a clone without history cannot compute.
- The build runs in `/var/tmp`, not in `/tmp`, which is often a tmpfs too small for the build tree, and the directory is deleted at the end.
- `.tag` is written last: an interrupted build leaves the install without `.tag`, so the next run rebuilds instead of trusting an incomplete install, and a run at the version already installed does nothing.

To update, run the script of section 2 again.

## 3. Verify

```bash
d=$(mktemp -d); cd "$d"; export PATH=/opt/yosys/bin:$PATH
cat > f.sv <<'EOF'
module t (input clk);
  reg [1:0] c = 0;
  always @(posedge clk) c <= c + 1;
  always @* assert(c <= 3);
endmodule
EOF
cat > f.sby <<'EOF'
[options]
mode prove
depth 5
[engines]
smtbmc z3
[script]
read_verilog -formal -sv f.sv
prep -top t
[files]
f.sv
EOF
yosys -V
sby -f f.sby | tail -n 1
cd /; rm -rf "$d"
```

## 4. Global PATH

Adds the binaries to the global `PATH`, by creating a wrapper for each one in `/usr/local/bin`:

```bash
for f in /opt/yosys/bin/*; do
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
