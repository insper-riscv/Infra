# Level 1 of the images: GHDL, Yosys with SymbiYosys, the GHDL plugin for Yosys, the SMT solvers Yices,
# Bitwuzla and Boolector, uv, Python with cocotb, the static analysis tools and riscv-tools, for
# linux/amd64 and linux/arm64. GHDL, Yosys and the solvers are copied from base-ghdl, base-yosys,
# base-yices, base-bitwuzla and base-boolector. See docs/en/docker/ci-vhdl.md.
#
#   docker buildx build --platform linux/amd64,linux/arm64 -f docker/ci/vhdl/Dockerfile -t ci-vhdl \
#     --build-arg UV_VERSION=<0.x.y> .

ARG BASE_IMAGE=ubuntu:26.04
# Python and cocotb move together (cocotb fixes the Python version); click is what sby imports.
ARG PYTHON_VERSION=3.14
ARG COCOTB_VERSION=2.1.0
ARG CLICK_VERSION=8.5.0
ARG GHDL_IMAGE=ghcr.io/insper-riscv/base-ghdl:latest
ARG YOSYS_IMAGE=ghcr.io/insper-riscv/base-yosys:latest
ARG YICES_IMAGE=ghcr.io/insper-riscv/base-yices:latest
ARG BITWUZLA_IMAGE=ghcr.io/insper-riscv/base-bitwuzla:latest
ARG BOOLECTOR_IMAGE=ghcr.io/insper-riscv/base-boolector:latest
# The commit of insper-riscv/Tools to install: the CLI (riscv-tools) comes with the image. The CI images
# workflow passes the commit of the latest stable release (Tools publishes it only after its CI succeeded); this
# default is for local builds.
ARG TOOLS_COMMIT=c20e29e7a589f34656de80775cec8145511a47f6
# The commit of ghdl/ghdl-yosys-plugin to build: the one tagged ghdl-v6.0.0, which builds against the
# GHDL 6.0.0 and the Yosys 0.70 of the image. The plugin links libghdl and uses the Yosys C++ API, so a
# new GHDL or Yosys can need a newer commit (the build below fails when it does).
ARG GHDL_YOSYS_PLUGIN_COMMIT=7b8075d21c602d53932dd82e168ee5f4635e81ad

FROM ${GHDL_IMAGE} AS ghdl
FROM ${YOSYS_IMAGE} AS yosys
FROM ${YICES_IMAGE} AS yices
FROM ${BITWUZLA_IMAGE} AS bitwuzla
FROM ${BOOLECTOR_IMAGE} AS boolector

FROM ${BASE_IMAGE} AS toolchain

# libglib2.0-0t64 for quartus from host to be able to talk to the internal server;
# git, make, curl, jq and ca-certificates for whoever uses the image (jq reads the JSON of the formal results);
# libgnat, libllvm, zlib1g-dev and libedit2 for GHDL;
# gcc and libc6-dev link what GHDL elaborates;
# g++ builds cocotb on arm64;
# libreadline8t64, libtcl8.6 and libffi8 for Yosys;
# tcl (tclsh) so the tests of riscv-tools run the Quartus Tcl scripts it generates instead of skipping them;
# libgmp10 for yices-smt2, and libstdc++6 and libgcc-s1 for btorsim of Boolector (Bitwuzla and the
# other Boolector executables are static).
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libglib2.0-0t64 \
      git make curl jq ca-certificates \
      libgnat-14 libllvm21 zlib1g-dev libedit2 \
      gcc libc6-dev \
      g++ \
      libreadline8t64 libtcl8.6 libffi8 tcl \
      libgmp10 libstdc++6 libgcc-s1 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghdl /opt/ghdl /opt/ghdl
COPY --from=yosys /opt/yosys /opt/yosys

# Builds ghdl.so against the GHDL and the Yosys above and installs it where `yosys -m ghdl` looks for
# it. Only that file is copied to the final image.
FROM toolchain AS ghdl-plugin
ARG GHDL_YOSYS_PLUGIN_COMMIT
RUN git init /plugin \
 && git -C /plugin fetch --depth 1 https://github.com/ghdl/ghdl-yosys-plugin "${GHDL_YOSYS_PLUGIN_COMMIT}" \
 && git -C /plugin checkout FETCH_HEAD \
 && make -C /plugin -j"$(nproc)" GHDL=/opt/ghdl/bin/ghdl YOSYS_CONFIG=/opt/yosys/bin/yosys-config \
 && make -C /plugin install GHDL=/opt/ghdl/bin/ghdl YOSYS_CONFIG=/opt/yosys/bin/yosys-config

FROM toolchain

COPY --from=ghdl-plugin /opt/yosys/share/yosys/plugins/ghdl.so /opt/yosys/share/yosys/plugins/ghdl.so
COPY --from=yices /opt/yices /opt/yices
COPY --from=bitwuzla /opt/bitwuzla /opt/bitwuzla
COPY --from=boolector /opt/boolector /opt/boolector

# uv, from the official installer of the version given, in /usr/local/bin. The installer checks the
# binary against the SHA-256 it carries, and UV_UNMANAGED_INSTALL leaves no receipt or updater.
ARG UV_VERSION
RUN test -n "${UV_VERSION}" || { echo "pass --build-arg UV_VERSION=<0.x.y>"; exit 1; } \
 && curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" -o /tmp/uv-install.sh \
 && UV_UNMANAGED_INSTALL=/usr/local/bin sh /tmp/uv-install.sh \
 && rm /tmp/uv-install.sh \
 && uv --version

ENV PATH=/opt/ghdl/bin:/opt/yosys/bin:/opt/yices/bin:/opt/bitwuzla/bin:/opt/boolector/bin:$PATH

# Python from uv in a directory every user reads, with cocotb and click installed in it and python3
# on the PATH. --break-system-packages because uv marks its Python as externally managed.
ARG PYTHON_VERSION
ARG COCOTB_VERSION
ARG CLICK_VERSION
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_PYTHON_PREFERENCE=only-managed
RUN uv python install "${PYTHON_VERSION}" \
 && python="$(uv python find "${PYTHON_VERSION}")" \
 && uv pip install --break-system-packages --python "$python" "cocotb==${COCOTB_VERSION}" "click==${CLICK_VERSION}" \
 && ln -s "$python" /usr/local/bin/python3 \
 && ln -s "$python" /usr/local/bin/python \
 && chmod -R a+rX /opt/uv

# The static analysis tools in their own virtual environment (versions in static-analysis.txt), with
# the executables linked into /usr/local/bin. They do not see a project's dependencies: pylint, pyright
# and deptry of a project still run with `uv run` in its environment.
COPY docker/ci/vhdl/static-analysis.txt /tmp/static-analysis.txt
RUN python="$(uv python find "${PYTHON_VERSION}")" \
 && uv venv --python "$python" /opt/static-analysis \
 && uv pip install --python /opt/static-analysis/bin/python -r /tmp/static-analysis.txt \
 && for t in ruff pycodestyle pydocstyle pylint pyright pyrefly deptry complexipy codeclone semgrep; do \
      ln -s "/opt/static-analysis/bin/$t" "/usr/local/bin/$t"; \
    done \
 && rm /tmp/static-analysis.txt \
 && chmod -R a+rX /opt/static-analysis

# riscv-tools, from the commit of Tools given, in its own environment with the executable in
# /usr/local/bin (the source is public, so no credentials are needed).
ARG TOOLS_COMMIT
ARG TOOLS_VERSION=
RUN UV_TOOL_DIR=/opt/riscv-tools UV_TOOL_BIN_DIR=/usr/local/bin \
    uv tool install "git+https://github.com/insper-riscv/Tools@${TOOLS_COMMIT}" \
 && { echo "${TOOLS_COMMIT}"; echo "${TOOLS_VERSION:-unknown} ($(echo "${TOOLS_COMMIT}" | cut -c1-7))"; } > /opt/riscv-tools/.tag \
 && chmod -R a+rX /opt/riscv-tools

# Fail the build here, not in a user's CI: GHDL runs a VHDL-2008 design, and sby proves a property with
# each engine (the solvers Yices, Bitwuzla and Boolector, and the abc engines) and reports, with
# status 2, one that does not hold.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    printf '%s\n' \
      'library ieee; use ieee.std_logic_1164.all;' \
      'entity t is end;' \
      'architecture a of t is signal s : std_logic := '"'"'1'"'"'; begin' \
      '  process begin assert s = '"'"'1'"'"' severity failure; report "ghdl ok"; wait; end process;' \
      'end;' > t.vhd; \
    echo "ghdl      $(ghdl --version | head -n 1) (.tag $(tail -n 1 /opt/ghdl/.tag))"; \
    ghdl -a --std=08 t.vhd; \
    ghdl --elab-run --std=08 t; \
    printf '%s\n' \
      'library ieee; use ieee.std_logic_1164.all;' \
      'entity p is port (a, b : in std_logic; y : out std_logic); end;' \
      'architecture r of p is begin y <= a and b; end;' > p.vhd; \
    yosys -q -m ghdl -p 'ghdl --std=08 p.vhd -e p; hierarchy -top p; proc; select -assert-count 1 t:$and'; \
    echo "yosys     $(yosys -V) (.tag $(tail -n 1 /opt/yosys/.tag))"; \
    echo "uv        $(uv --version)"; \
    python3 -c "import sys, cocotb; assert sys.version_info[:2] == (3, 14); print('python   ', sys.version.split()[0], 'cocotb', cocotb.__version__)"; \
    echo "gcc host  $(gcc --version | head -n 1)"; \
    for t in ruff pycodestyle pydocstyle pylint pyright pyrefly deptry complexipy codeclone semgrep; do \
      echo "$t  $("$t" --version 2>&1 | head -n 1)"; \
    done; \
    riscv-tools --help > /dev/null; \
    echo "tools     riscv-tools (.tag $(tail -n 1 /opt/riscv-tools/.tag))"; \
    echo "sby       $(sby --version 2>&1 | head -n 1) (.tag $(tail -n 1 /opt/yosys/.sby.tag))"; \
    echo "yices     $(yices-smt2 --version | head -n 1) (.tag $(tail -n 1 /opt/yices/.tag))"; \
    echo "bitwuzla  $(bitwuzla --version) (.tag $(tail -n 1 /opt/bitwuzla/.tag))"; \
    echo "boolector $(boolector --version) (.tag $(tail -n 1 /opt/boolector/.tag))"; \
    printf '%s\n' \
      'module t (input clk, input en);' \
      '  reg [3:0] c = 0;' \
      '  always @(posedge clk) if (en) c <= (c == 9) ? 4'"'"'d0 : c + 1;' \
      '  always @* assert(c <= 9);' \
      'endmodule' > f.sv; \
    sed 's/c <= 9/c <= 8/' f.sv > g.sv; \
    sby_file() { printf '%s\n' '[options]' "mode $2" 'depth 12' "$4" '[engines]' "$3" \
      '[script]' "read_verilog -formal -sv $5" 'prep -top t' '[files]' "$5" > "$1.sby"; }; \
    for e in yices bitwuzla boolector; do \
      sby_file "$e" prove "smtbmc $e" '' f.sv; \
      sby -f "$e.sby" > "$e.log" 2>&1 || { cat "$e.log"; exit 1; }; \
      echo "proof     smtbmc $e: $(tail -n 1 "$e.log")"; \
    done; \
    sby_file abc-bmc3 bmc 'abc bmc3' 'aigsmt none' f.sv; \
    sby_file abc-pdr prove 'abc pdr' 'aigsmt none' f.sv; \
    for e in abc-bmc3 abc-pdr; do \
      sby -f "$e.sby" > "$e.log" 2>&1 || { cat "$e.log"; exit 1; }; \
      echo "proof     $e: $(tail -n 1 "$e.log")"; \
    done; \
    sby_file neg bmc 'abc bmc3' 'aigsmt none' g.sv; \
    rc=0; sby -f neg.sby > neg.log 2>&1 || rc=$?; \
    [ "$rc" = 2 ] || { cat neg.log; echo "a refuted property must end with status 2, got $rc"; exit 1; }; \
    echo "refuted   abc-bmc3: status 2 for a property that does not hold"; \
    cd /; rm -rf "$d"

WORKDIR /workspace
