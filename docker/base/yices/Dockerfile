# Yices 2 built from source, alone: the SMT solver that SymbiYosys (sby) runs as `smtbmc yices`
# (the `yices-smt2` executable). The published image holds just the install directory, and the
# complete image (docker/ci/vhdl/Dockerfile) copies it from there.
#
# The commit of SRI-CSL/yices2 to build has no default:
#
#   docker build -f docker/base/yices/Dockerfile -t base-yices \
#     --build-arg YICES_COMMIT="$(git ls-remote https://github.com/SRI-CSL/yices2 'refs/tags/Yices-2.6.5^{}' 'refs/tags/Yices-2.6.5' | tail -n 1 | cut -f1)" .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG YICES_COMMIT
ARG YICES_VERSION=

RUN test -n "${YICES_COMMIT}" \
 || { echo "pass --build-arg YICES_COMMIT=<commit>"; exit 1; }

# autoconf generates the configure script, gperf the keyword tables and GMP is the arbitrary-precision
# library Yices links.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential autoconf gperf git ca-certificates libgmp-dev \
 && rm -rf /var/lib/apt/lists/*

RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/SRI-CSL/yices2 "${YICES_COMMIT}" \
 && git -C /src checkout FETCH_HEAD

# Only the executables go in the install directory: the headers and libraries are for whoever links
# Yices into a program, and sby runs `yices-smt2`.
RUN cd /src \
 && autoconf \
 && ./configure --prefix=/opt/yices \
 && make -j"$(nproc)" \
 && make install \
 && find /opt/yices -mindepth 1 -maxdepth 1 ! -name bin -exec rm -rf {} + \
 && strip /opt/yices/bin/* \
 && { echo "${YICES_COMMIT}"; echo "${YICES_VERSION:-unknown} ($(echo "${YICES_COMMIT}" | cut -c1-7))"; } > /opt/yices/.tag \
 && rm -rf /src

# Fail the build, before anything is published, if the executable does not run or does not solve:
# a small query over bit-vectors, in the SMT-LIB the sby sends.
RUN set -e; export PATH=/opt/yices/bin:$PATH; \
    yices-smt2 --version | head -n 1; \
    printf '%s\n' \
      '(set-logic QF_BV)' \
      '(declare-const x (_ BitVec 8))' \
      '(assert (= (bvadd x #x01) #x00))' \
      '(check-sat)' | yices-smt2 | tee /tmp/out.txt; \
    head -n 1 /tmp/out.txt | grep -qx sat; \
    rm /tmp/out.txt


FROM scratch
ARG YICES_COMMIT
LABEL yices.commit="${YICES_COMMIT}"
COPY --from=build /opt/yices /opt/yices
