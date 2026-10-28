# Level 4 of the images, the final one: the ELF image plus GTKWave, the GHDL plugin for Yosys and the
# user dev, for a Dev Container. GTKWave is copied from base-gtkwave. See docs/en/docker/dev-tools.md.
#
#   docker build -f docker/dev-tools/Dockerfile -t dev_tools .
#   docker run --rm -it -v "$PWD:/work" dev_tools

ARG ACT4_IMAGE=ghcr.io/insper-riscv/ci-act4:latest
ARG GTKWAVE_IMAGE=ghcr.io/insper-riscv/base-gtkwave:latest

# The commit of ghdl/ghdl-yosys-plugin to build: the one tagged ghdl-v6.0.0, which builds against the
# GHDL 6.0.0 and the Yosys 0.70 of the image. The plugin links libghdl and uses the Yosys C++ API, so a
# new GHDL or Yosys can need a newer commit (the build below fails when it does).
ARG GHDL_YOSYS_PLUGIN_COMMIT=7b8075d21c602d53932dd82e168ee5f4635e81ad

FROM ${GTKWAVE_IMAGE} AS gtkwave

# Builds ghdl.so against the GHDL and the Yosys already in ci-act4, and installs it where
# `yosys -m ghdl` looks for it. Only that file is copied to the final image.
FROM ${ACT4_IMAGE} AS ghdl-plugin
ARG GHDL_YOSYS_PLUGIN_COMMIT
RUN git init /plugin \
 && git -C /plugin fetch --depth 1 https://github.com/ghdl/ghdl-yosys-plugin "${GHDL_YOSYS_PLUGIN_COMMIT}" \
 && git -C /plugin checkout FETCH_HEAD \
 && make -C /plugin -j"$(nproc)" GHDL=/opt/ghdl/bin/ghdl YOSYS_CONFIG=/opt/yosys/bin/yosys-config \
 && make -C /plugin install GHDL=/opt/ghdl/bin/ghdl YOSYS_CONFIG=/opt/yosys/bin/yosys-config

FROM ${ACT4_IMAGE}

# build-essential and pkg-config for the projects that compile C; gnat is the Ada runtime GHDL's
# own builds and some libraries need. The rest are what GTKWave links against and uses at run time
# (GTK 3, with its Wayland and X11 backends, an icon theme and the MIME database); GTKWave itself is
# built in its own image and copied. GTK loads EGL at run time (through libepoxy), so ldd does not
# list it: without libegl1 and a Mesa driver GTKWave aborts on Wayland with "Couldn't open libEGL.so.1".
# libicu78 is the globalization library the .NET language servers of editor extensions (such as V4P)
# need; without it they abort on start.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential pkg-config gnat \
      libgtk-3-0t64 libjudydebian1 libbz2-1.0 liblzma5 \
      libegl1 libegl-mesa0 libgl1 libgl1-mesa-dri \
      adwaita-icon-theme shared-mime-info libicu78 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gtkwave /opt/gtkwave /opt/gtkwave
ENV PATH=/opt/gtkwave/bin:$PATH

COPY --from=ghdl-plugin /opt/yosys/share/yosys/plugins/ghdl.so /opt/yosys/share/yosys/plugins/ghdl.so

# Fail the build if Yosys cannot load the plugin and synthesize a VHDL design through it.
RUN set -e; d="$(mktemp -d)"; cd "$d"; \
    printf '%s\n' \
      'library ieee; use ieee.std_logic_1164.all;' \
      'entity t is port (a, b : in std_logic; y : out std_logic); end;' \
      'architecture r of t is begin y <= a and b; end;' > t.vhd; \
    yosys -q -m ghdl -p 'ghdl --std=08 t.vhd -e t; hierarchy -top t; proc; select -assert-count 1 t:$and' \
 && cd / && rm -rf "$d"

# Fail the build if GTKWave lacks a library, linked or loaded at run time (EGL).
RUN ! ldd /opt/gtkwave/bin/gtkwave | grep "not found" \
 && ldconfig -p | grep -q "libEGL.so.1"

RUN useradd --create-home --shell /bin/bash dev \
 && mkdir -p /work \
 && chown dev:dev /work

USER dev
WORKDIR /work
CMD ["/bin/bash"]
