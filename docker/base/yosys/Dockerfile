# Yosys and SymbiYosys (sby) built from source, alone: the formal tools that prove properties of
# the Verilog netlist GHDL synthesizes from the VHDL. The published image holds just the install
# directory, and the complete image (Dockerfile) copies it from there.
#
# The two repositories are released in step (Yosys v0.N and sby v0.N), so the image holds one of
# each with the same version. The commits to build have no default:
#
#   docker build -f docker/base/yosys/Dockerfile -t base-yosys \
#     --build-arg YOSYS_COMMIT="$(git ls-remote https://github.com/YosysHQ/yosys 'refs/tags/v0.69^{}' | cut -f1)" \
#     --build-arg SBY_COMMIT="$(git ls-remote https://github.com/YosysHQ/sby 'refs/tags/v0.69^{}' | cut -f1)" .
#
# The SystemVerilog front-end based on Slang (the largest part of the build) is left out: the
# properties are read with the built-in `read_verilog -formal -sv`.

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG YOSYS_COMMIT
ARG SBY_COMMIT

RUN test -n "${YOSYS_COMMIT}" && test -n "${SBY_COMMIT}" \
 || { echo "pass --build-arg YOSYS_COMMIT=<commit> --build-arg SBY_COMMIT=<commit>"; exit 1; }

# cmake, a C++20 compiler (build-essential), flex and bison build Yosys; readline, libffi, Tcl
# and zlib are the optional libraries it uses when they are there. python3 runs the build
# scripts, and python3-click and z3 are only for the check at the end of this stage.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates python3 pkg-config gawk bison flex \
      libreadline-dev libffi-dev libfl-dev tcl-dev zlib1g-dev \
      python3-click z3 \
 && rm -rf /var/lib/apt/lists/*

# The submodules a build without Slang needs: ABC (logic optimization), symfpu (the floating-point
# cells) and the three libraries Yosys bundles.
RUN git init /yosys \
 && git -C /yosys fetch --depth 1 https://github.com/YosysHQ/yosys "${YOSYS_COMMIT}" \
 && git -C /yosys checkout FETCH_HEAD \
 && git -C /yosys submodule update --init --depth 1 abc libs/symfpu libs/cxxopts libs/fmt libs/tomlplusplus

RUN cd /yosys \
 && cmake -B build . \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/yosys \
      -DYOSYS_USE_BUNDLED_LIBS=ON \
      -DYOSYS_WITHOUT_SLANG=ON \
      -DYOSYS_ENABLE_UNIT_TESTS=OFF \
 && cmake --build build --parallel "$(nproc)" \
 && cmake --install build --strip \
 && echo "${YOSYS_COMMIT}" > /opt/yosys/.tag \
 && rm -rf /yosys

# sby is Python: it installs next to Yosys, into the same share/yosys/python3. Its version string comes
# from `git describe`, which a clone of one commit cannot answer, so it is given: the highest release tag
# that points at the commit (two releases can share one), or the short commit when there is none.
RUN git init /sby \
 && git -C /sby fetch --depth 1 https://github.com/YosysHQ/sby "${SBY_COMMIT}" \
 && git -C /sby checkout FETCH_HEAD \
 && tag="$(git ls-remote --tags https://github.com/YosysHQ/sby | sed -n "s|^${SBY_COMMIT}[[:space:]]refs/tags/\(.*\)^{}\$|\1|p" | sort -V | tail -n 1)" \
 && make -C /sby install PREFIX=/opt/yosys YOSYS_RELEASE_VERSION="SBY ${tag:-$(printf %.7s "${SBY_COMMIT}")}" \
 && echo "${SBY_COMMIT}" > /opt/yosys/.sby.tag \
 && rm -rf /sby

# Fail the build, before anything is published, if the two do not work together: a small proof
# with the z3 solver.
RUN set -e; d="$(mktemp -d)"; cd "$d"; export PATH=/opt/yosys/bin:$PATH; \
    yosys -V; \
    printf '%s\n' \
      'module t (input clk);' \
      '  reg [1:0] c = 0;' \
      '  always @(posedge clk) c <= c + 1;' \
      '  always @* assert(c <= 3);' \
      'endmodule' > f.sv; \
    printf '%s\n' '[options]' 'mode prove' 'depth 5' '[engines]' 'smtbmc z3' \
      '[script]' 'read_verilog -formal -sv f.sv' 'prep -top t' '[files]' 'f.sv' > f.sby; \
    sby -f f.sby > sby.log 2>&1 || { cat sby.log; exit 1; }; \
    tail -n 1 sby.log; \
    cd /; rm -rf "$d"


FROM scratch
ARG YOSYS_COMMIT
ARG SBY_COMMIT
LABEL yosys.commit="${YOSYS_COMMIT}"
LABEL sby.commit="${SBY_COMMIT}"
COPY --from=build /opt/yosys /opt/yosys
