# Level 1 of the images: GHDL, Yosys with SymbiYosys, uv, and Python with cocotb, for linux/amd64
# and linux/arm64. GHDL and Yosys are copied from base-ghdl and base-yosys. See docs/en/docker/ci-vhdl.md.
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

FROM ${GHDL_IMAGE} AS ghdl
FROM ${YOSYS_IMAGE} AS yosys

FROM ${BASE_IMAGE}

# libglib2.0-0t64 for quartus from host to be able to talk to the internal server;
# git, make, curl and ca-certificates for whoever uses the image;
# libgnat, libllvm, zlib1g-dev and libedit2 for GHDL;
# gcc and libc6-dev link what GHDL elaborates;
# g++ builds cocotb on arm64;
# libreadline8t64, libtcl8.6 and libffi8 for Yosys.
# z3 and boolector for sby; 
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libglib2.0-0t64 \
      git make curl ca-certificates \
      libgnat-14 libllvm21 zlib1g-dev libedit2 \
      gcc libc6-dev \
      g++ \
      libreadline8t64 libtcl8.6 libffi8 \
      z3 boolector \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghdl /opt/ghdl /opt/ghdl
COPY --from=yosys /opt/yosys /opt/yosys

# uv, from the official installer of the version given, in /usr/local/bin. The installer checks the
# binary against the SHA-256 it carries, and UV_UNMANAGED_INSTALL leaves no receipt or updater.
ARG UV_VERSION
RUN test -n "${UV_VERSION}" || { echo "pass --build-arg UV_VERSION=<0.x.y>"; exit 1; } \
 && curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" -o /tmp/uv-install.sh \
 && UV_UNMANAGED_INSTALL=/usr/local/bin sh /tmp/uv-install.sh \
 && rm /tmp/uv-install.sh \
 && uv --version

ENV PATH=/opt/ghdl/bin:/opt/yosys/bin:$PATH

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

# Fail the build here, not in a user's CI: GHDL runs a VHDL-2008 design and sby proves a property.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    printf '%s\n' \
      'library ieee; use ieee.std_logic_1164.all;' \
      'entity t is end;' \
      'architecture a of t is signal s : std_logic := '"'"'1'"'"'; begin' \
      '  process begin assert s = '"'"'1'"'"' severity failure; report "ghdl ok"; wait; end process;' \
      'end;' > t.vhd; \
    echo "ghdl      $(ghdl --version | head -n 1) (commit $(cat /opt/ghdl/.tag))"; \
    ghdl -a --std=08 t.vhd; \
    ghdl --elab-run --std=08 t; \
    echo "yosys     $(yosys -V) (commit $(cat /opt/yosys/.tag))"; \
    echo "uv        $(uv --version)"; \
    python3 -c "import sys, cocotb; assert sys.version_info[:2] == (3, 14); print('python   ', sys.version.split()[0], 'cocotb', cocotb.__version__)"; \
    echo "gcc host  $(gcc --version | head -n 1)"; \
    printf '%s\n' \
      'module t (input clk);' \
      '  reg [1:0] c = 0;' \
      '  always @(posedge clk) c <= c + 1;' \
      '  always @* assert(c <= 3);' \
      'endmodule' > f.sv; \
    printf '%s\n' '[options]' 'mode prove' 'depth 5' '[engines]' 'smtbmc z3' \
      '[script]' 'read_verilog -formal -sv f.sv' 'prep -top t' '[files]' 'f.sv' > f.sby; \
    sby -f f.sby > sby.log 2>&1 || { cat sby.log; exit 1; }; \
    echo "sby       $(sby --version 2>&1 | head -n 1) (commit $(cat /opt/yosys/.sby.tag)); proof: $(tail -n 1 sby.log)"; \
    cd /; rm -rf "$d"

WORKDIR /workspace
