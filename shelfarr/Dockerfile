ARG BUILD_FROM=ghcr.io/pedro-revez-silva/shelfarr:latest
FROM ${BUILD_FROM}

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

ARG BUILD_VERSION
LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.arch="aarch64|amd64"

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:80/up || exit 1

ENTRYPOINT ["/run.sh"]
