# Sail RISC-V, the formal model of the RISC-V ISA, alone: the executable `sail_riscv_sim`, built
# from one commit of riscv/sail-riscv. The ACT4 test generator runs it to compute the expected
# result of every test. The published image holds just the install directory, and the ACT4 image
# (docker/ci/act4/Dockerfile) copies it from there.
#
# The commit has no default (the Sail image workflow passes the latest one whose upstream CI
# succeeded). SAIL_VERSION is the release number that commit declares (cmake/project_version.cmake),
# which is what `sail_riscv_sim --version` prints and what ACT4 compares against its own requirement;
# the build fails if the two differ.
#
#   docker build -f docker/base/sail/Dockerfile -t base-sail \
#     --build-arg SAIL_COMMIT=<40 hex digits> --build-arg SAIL_VERSION=0.16 .

ARG BASE_IMAGE=ubuntu:26.04

FROM ${BASE_IMAGE} AS build
ARG TARGETARCH
ARG SAIL_COMMIT
ARG SAIL_VERSION

RUN printf '%s' "${SAIL_COMMIT}" | grep -Eq '^[0-9a-f]{40}$' && test -n "${SAIL_VERSION}" \
 || { echo "pass --build-arg SAIL_COMMIT=<40 hex digits> and SAIL_VERSION"; exit 1; }

# cmake, ninja and g++ build the model; libgmp-dev brings the static libgmp the static link needs;
# git fetches the commit; curl and ca-certificates download the Sail compiler.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git cmake ninja-build g++ pkg-config libgmp-dev \
 && rm -rf /var/lib/apt/lists/*

# Exactly the commit asked for, checked out by its hash.
RUN git init /src \
 && git -C /src fetch --depth 1 https://github.com/riscv/sail-riscv "${SAIL_COMMIT}" \
 && git -C /src checkout --quiet FETCH_HEAD \
 && test "$(git -C /src rev-parse HEAD)" = "${SAIL_COMMIT}"

# The Sail compiler that commit requires (cmake/sail_required_version.txt), as the binary release of
# rems-project/sail, named by the architecture of the machine (x86_64, aarch64).
RUN case "${TARGETARCH}" in amd64) arch=x86_64 ;; arm64) arch=aarch64 ;; *) echo "no Sail binary for ${TARGETARCH}"; exit 1 ;; esac \
 && compiler="$(tr -d '[:space:]' < /src/cmake/sail_required_version.txt)" \
 && curl -fsSL "https://github.com/rems-project/sail/releases/download/${compiler}-binary/sail-Linux-${arch}.tar.gz" \
    | tar -xz -C /usr/local --strip-components=1 \
 && sail --version

# Static, as the upstream release builds it, so the executable runs in images that do not have libgmp.
RUN cmake -S /src -B /build -G Ninja -DCMAKE_BUILD_TYPE=Release -DSTATIC=TRUE -DENABLE_LTO=TRUE \
      -DENABLE_RISCV_TESTS=FALSE \
 && cmake --build /build

# Only the executable is installed. `cmake --install` also installs files of the dependencies that a
# given commit may not have where its install rules look for them, and ACT4 needs just the executable.
RUN install -D /build/c_emulator/sail_riscv_sim /opt/riscv-foundation/sail/bin/sail_riscv_sim \
 && echo "${SAIL_COMMIT}" > /opt/riscv-foundation/sail/.tag

# Fail the build, before anything is published, if the binary does not run, prints a version other
# than the one declared, or lacks a library that this image does not install.
RUN test "$(/opt/riscv-foundation/sail/bin/sail_riscv_sim --version)" = "${SAIL_VERSION}" \
 && ! ldd /opt/riscv-foundation/sail/bin/sail_riscv_sim | grep "not found"


FROM scratch
ARG SAIL_VERSION
ARG SAIL_COMMIT
LABEL sail-riscv.version="${SAIL_VERSION}" \
      sail-riscv.commit="${SAIL_COMMIT}"
COPY --from=build /opt/riscv-foundation/sail /opt/riscv-foundation/sail
