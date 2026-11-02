# Boolector built from source, alone: the SMT solver for bit-vectors and arrays that SymbiYosys
# (sby) runs as `smtbmc boolector`, with its model checker `btormc` (the `btor` engine). The
# published image holds just the install directory, and the complete image
# (docker/ci/vhdl/Dockerfile) copies it from there.
#
# It is built here, and not installed with apt, because the Ubuntu package is Boolector 1.5, which
# does not run in the incremental SMT-LIB mode (`--smt2 -i`) that yosys-smtbmc uses.
#
# The commit of Boolector/boolector to build has no default:
#
#   docker build -f docker/base/boolector/Dockerfile -t base-boolector \
#     --build-arg BOOLECTOR_COMMIT="$(git ls-remote https://github.com/Boolector/boolector 'refs/tags/3.2.4^{}' 'refs/tags/3.2.4' | tail -n 1 | cut -f1)" .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG BOOLECTOR_COMMIT

RUN test -n "${BOOLECTOR_COMMIT}" \
 || { echo "pass --build-arg BOOLECTOR_COMMIT=<commit>"; exit 1; }

# cmake builds Boolector and the two projects its scripts download and build next to it (the CaDiCaL
# SAT solver and btor2tools, the parser of the BTOR2 format); curl and wget fetch them, and GMP is the
# arbitrary-precision library it links.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates curl wget python3 pkg-config libgmp-dev m4 \
 && rm -rf /var/lib/apt/lists/*

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/Boolector/boolector "${BOOLECTOR_COMMIT}" \
 && git -C /src checkout FETCH_HEAD

# btor2tools declares a cmake_minimum_required that the CMake of Ubuntu 26.04 rejects, so the
# minimum policy is given. `make install` does not install btorsim, which sby calls to replay a
# counterexample of the btor engine, so it is copied from the btor2tools build.
ENV CMAKE_POLICY_VERSION_MINIMUM=3.5
RUN cd /src \
 && ./contrib/setup-cadical.sh \
 && ./contrib/setup-btor2tools.sh \
 && ./configure.sh --prefix /opt/boolector \
 && cd build \
 && make -j"$(nproc)" \
 && make install \
 && find /src/deps/btor2tools -name btorsim -type f -exec install -m 0755 {} /opt/boolector/bin/btorsim \; \
 && find /opt/boolector -mindepth 1 -maxdepth 1 ! -name bin -exec rm -rf {} + \
 && strip /opt/boolector/bin/* \
 && echo "${BOOLECTOR_COMMIT}" > /opt/boolector/.tag \
 && rm -rf /src

# Fail the build, before anything is published, if an executable does not run, or if Boolector does
# not answer in the incremental mode yosys-smtbmc uses: a small query over bit-vectors.
RUN set -e; export PATH=/opt/boolector/bin:$PATH; \
    boolector --version; \
    command -v btormc btorsim; \
    printf '%s\n' \
      '(set-logic QF_BV)' \
      '(declare-const x (_ BitVec 8))' \
      '(assert (= (bvadd x #x01) #x00))' \
      '(check-sat)' | boolector --smt2 -i | tee /tmp/out.txt; \
    head -n 1 /tmp/out.txt | grep -qx sat; \
    rm /tmp/out.txt


FROM scratch
ARG BOOLECTOR_COMMIT
LABEL boolector.commit="${BOOLECTOR_COMMIT}"
COPY --from=build /opt/boolector /opt/boolector
