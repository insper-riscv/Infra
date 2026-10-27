# Level 4 of the images, the final one: the ELF image plus GTKWave and the user dev, for a Dev
# Container. GTKWave is copied from base-gtkwave. See docs/en/docker/dev-tools.md.
#
#   docker build -f docker/dev-tools/Dockerfile -t dev_tools .
#   docker run --rm -it -v "$PWD:/work" dev_tools

ARG ACT4_IMAGE=ghcr.io/insper-riscv/ci-act4:latest
ARG GTKWAVE_IMAGE=ghcr.io/insper-riscv/base-gtkwave:latest

FROM ${GTKWAVE_IMAGE} AS gtkwave

FROM ${ACT4_IMAGE}

# build-essential and pkg-config for the projects that compile C; gnat is the Ada runtime GHDL's
# own builds and some libraries need. The rest are what GTKWave links against and uses at run time
# (GTK 3, with its Wayland and X11 backends, an icon theme and the MIME database); GTKWave itself is
# built in its own image and copied. GTK loads EGL at run time (through libepoxy), so ldd does not
# list it: without libegl1 and a Mesa driver GTKWave aborts on Wayland with "Couldn't open libEGL.so.1".
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential pkg-config gnat \
      libgtk-3-0t64 libjudydebian1 libbz2-1.0 liblzma5 \
      libegl1 libegl-mesa0 libgl1 libgl1-mesa-dri \
      adwaita-icon-theme shared-mime-info \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gtkwave /opt/gtkwave /opt/gtkwave
ENV PATH=/opt/gtkwave/bin:$PATH

# Fail the build if GTKWave lacks a library, linked or loaded at run time (EGL).
RUN ! ldd /opt/gtkwave/bin/gtkwave | grep "not found" \
 && ldconfig -p | grep -q "libEGL.so.1"

RUN useradd --create-home --shell /bin/bash dev \
 && mkdir -p /work \
 && chown dev:dev /work

USER dev
WORKDIR /work
CMD ["/bin/bash"]
