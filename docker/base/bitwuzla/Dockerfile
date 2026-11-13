# Bitwuzla built from source, alone: the SMT solver for bit-vectors, floating point and arrays that
# SymbiYosys (sby) runs as `smtbmc bitwuzla`. The published image holds just the install directory,
# and the complete image (docker/ci/vhdl/Dockerfile) copies it from there.
#
# The commit of bitwuzla/bitwuzla to build has no default:
#
#   docker build -f docker/base/bitwuzla/Dockerfile -t base-bitwuzla \
#     --build-arg BITWUZLA_COMMIT="$(git ls-remote https://github.com/bitwuzla/bitwuzla 'refs/tags/0.9.1^{}' 'refs/tags/0.9.1' | tail -n 1 | cut -f1)" .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG BITWUZLA_COMMIT
ARG BITWUZLA_VERSION=

RUN test -n "${BITWUZLA_COMMIT}" \
 || { echo "pass --build-arg BITWUZLA_COMMIT=<commit>"; exit 1; }

# meson and ninja build it (through the configure.py of the project); GMP and MPFR are the
# arbitrary-precision libraries it links; cmake builds the dependencies it fetches (CaDiCaL, SymFPU).
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates python3 pkg-config meson ninja-build \
      libgmp-dev libmpfr-dev \
 && rm -rf /var/lib/apt/lists/*

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/bitwuzla/bitwuzla "${BITWUZLA_COMMIT}" \
 && git -C /src checkout FETCH_HEAD

# Only the executable goes in the install directory: the libraries and headers are for whoever
# links Bitwuzla into a program, and sby runs the executable.
RUN cd /src \
 && python3 configure.py --prefix /opt/bitwuzla \
 && cd build \
 && ninja \
 && ninja install \
 && find /opt/bitwuzla -mindepth 1 -maxdepth 1 ! -name bin -exec rm -rf {} + \
 && strip /opt/bitwuzla/bin/bitwuzla \
 && { echo "${BITWUZLA_COMMIT}"; echo "${BITWUZLA_VERSION:-unknown} $(git -C /src log -1 --format=%cs) ($(echo "${BITWUZLA_COMMIT}" | cut -c1-7))"; } > /opt/bitwuzla/.tag \
 && rm -rf /src

# Fail the build, before anything is published, if the executable does not run or does not solve:
# a small query over bit-vectors, in the SMT-LIB the sby sends.
RUN set -e; export PATH=/opt/bitwuzla/bin:$PATH; \
    bitwuzla --version; \
    printf '%s\n' \
      '(set-logic QF_BV)' \
      '(declare-const x (_ BitVec 8))' \
      '(assert (= (bvadd x #x01) #x00))' \
      '(check-sat)' \
      '(get-value (x))' | bitwuzla --lang smt2 | tee /tmp/out.txt; \
    head -n 1 /tmp/out.txt | grep -qx sat; \
    rm /tmp/out.txt


FROM scratch
ARG BITWUZLA_COMMIT
LABEL bitwuzla.commit="${BITWUZLA_COMMIT}"
COPY --from=build /opt/bitwuzla /opt/bitwuzla
