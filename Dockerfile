# -------------------
# The build container
# -------------------
FROM debian:bookworm-slim AS build

WORKDIR /usr/src/app

COPY . /usr/src/app

# Upgrade bookworm and install dependencies
RUN apt-get -y update && apt -y upgrade && apt-get -y install --no-install-recommends \
    ca-certificates \
    git \
    cmake \
    pkg-config \
    libusb-1.0-0-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Build and install RTL-SDR V4 drivers from osmocom
RUN git clone https://github.com/osmocom/rtl-sdr.git /tmp/rtl-sdr && \
    cd /tmp/rtl-sdr && \
    mkdir build && \
    cd build && \
    cmake ../ -DINSTALL_UDEV_RULES=ON -DDETACH_KERNEL_DRIVER=ON && \
    make && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/rtl-sdr

# Build rtl_ais
RUN make && \
    make install


# -------------------------
# The application container
# -------------------------
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="rtl-ais"
LABEL org.opencontainers.image.description="AIS decoding using RTL-SDR dongle"
LABEL org.opencontainers.image.authors="Bryan Klofas KF6ZEO bklofas@gmail"
LABEL org.opencontainers.image.source="https://github.com/bklofas/rtl-ais"

# Upgrade bookworm and install runtime dependencies
RUN apt-get -y update && apt -y upgrade && apt-get -y install --no-install-recommends \
    tini \
    libusb-1.0-0 &&\
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/src/app /
COPY --from=build /usr/local/lib/librtlsdr* /usr/local/lib/
COPY --from=build /usr/local/bin/rtl_* /usr/local/bin/
COPY --from=build /usr/local/include/rtl-sdr* /usr/local/include/

# Update library cache for RTL-SDR V4 libraries
RUN ldconfig

# Use tini as init.
ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/rtl_ais", "-n"]

