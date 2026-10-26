# syntax=docker/dockerfile:1
#
# Sail RISC-V, the formal model of the RISC-V ISA, alone: the executable `sail_riscv_sim` of a
# release of riscv/sail-riscv. The ACT4 test generator runs it to compute the expected result of
# every test. The published image holds just the install directory, and the ACT4 image
# (Dockerfile.act) copies it from there.
#
# The release and the SHA-256 of its two tarballs have no default (GitHub publishes the
# digest of each asset of a release):
#
#   docker build -f Dockerfile.sail -t infra-sail \
#     --build-arg SAIL_VERSION=0.16 \
#     --build-arg SAIL_SHA256_AMD64=<digest of sail-riscv-Linux-x86_64.tar.gz> \
#     --build-arg SAIL_SHA256_ARM64=<digest of sail-riscv-Linux-aarch64.tar.gz> .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG TARGETARCH
ARG SAIL_VERSION
ARG SAIL_SHA256_AMD64
ARG SAIL_SHA256_ARM64

RUN test -n "${SAIL_VERSION}" -a -n "${SAIL_SHA256_AMD64}" -a -n "${SAIL_SHA256_ARM64}" \
 || { echo "pass --build-arg SAIL_VERSION, SAIL_SHA256_AMD64 and SAIL_SHA256_ARM64"; exit 1; }

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

# The release names its tarballs by the architecture of the machine (x86_64, aarch64), not by the
# Docker one (amd64, arm64).
RUN case "${TARGETARCH}" in \
      amd64) asset=sail-riscv-Linux-x86_64.tar.gz;  sum="${SAIL_SHA256_AMD64}" ;; \
      arm64) asset=sail-riscv-Linux-aarch64.tar.gz; sum="${SAIL_SHA256_ARM64}" ;; \
      *) echo "no Sail release for ${TARGETARCH}"; exit 1 ;; \
    esac \
 && curl -fsSL -o /tmp/sail.tar.gz \
      "https://github.com/riscv/sail-riscv/releases/download/${SAIL_VERSION}/${asset}" \
 && echo "${sum#sha256:}  /tmp/sail.tar.gz" | sha256sum -c - \
 && mkdir -p /opt/sail \
 && tar -xzf /tmp/sail.tar.gz -C /opt/sail --strip-components=1 \
 && rm /tmp/sail.tar.gz \
 && echo "${SAIL_VERSION}" > /opt/sail/.tag

# Fail the build, before anything is published, if the binary does not run or lacks a library
# that this image does not install.
RUN /opt/sail/bin/sail_riscv_sim --version \
 && ! ldd /opt/sail/bin/sail_riscv_sim | grep "not found"


FROM scratch
ARG SAIL_VERSION
ARG SAIL_COMMIT
LABEL sail-riscv.version="${SAIL_VERSION}" \
      sail-riscv.commit="${SAIL_COMMIT}"
COPY --from=build /opt/sail /opt/sail
