# Hytale Dedicated Server Dockerfile
# Based on official Hytale Server Manual requirements

FROM eclipse-temurin:25-jdk

LABEL maintainer="Hytale Server Docker"
LABEL description="Hytale Dedicated Server with mods support and auto-download"

# Install dependencies for downloading and extracting
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r hytale && useradd -r -g hytale -m hytale

# Create server directory structure
RUN mkdir -p /opt/hytale/mods \
    && mkdir -p /opt/hytale/universe \
    && mkdir -p /opt/hytale/logs \
    && mkdir -p /opt/hytale/.cache \
    && mkdir -p /opt/hytale/backups \
    && mkdir -p /opt/hytale/downloads \
    && mkdir -p /opt/hytale/config \
    && mkdir -p /home/hytale/.config/hytale-downloader

WORKDIR /opt/hytale

# Download URL for hytale-downloader (update if URL changes)
# The downloader is available from the Hytale support documentation
ARG HYTALE_DOWNLOADER_URL="https://cdn.hytale.com/downloader/hytale-downloader.zip"

# Download and extract hytale-downloader
RUN curl -fsSL "${HYTALE_DOWNLOADER_URL}" -o /tmp/hytale-downloader.zip \
    && unzip /tmp/hytale-downloader.zip -d /opt/hytale/ \
    && chmod +x /opt/hytale/hytale-downloader* \
    && rm /tmp/hytale-downloader.zip \
    || echo "Warning: Could not download hytale-downloader. Manual server file copy required."

# Copy any pre-existing server files (optional, will be skipped if empty)
COPY --chown=hytale:hytale server/ ./server-files/

# Set ownership
RUN chown -R hytale:hytale /opt/hytale /home/hytale

# Switch to non-root user
USER hytale

# Expose UDP port (Hytale uses QUIC protocol over UDP)
EXPOSE 5520/udp

# Health check - basic process check since there's no HTTP endpoint by default
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD pgrep -f "HytaleServer.jar" || exit 1

# Environment variables for JVM tuning
ENV JAVA_MIN_HEAP="2G"
ENV JAVA_MAX_HEAP="4G"
ENV SERVER_PORT="5520"
ENV AUTH_MODE="authenticated"
ENV ENABLE_BACKUP="false"
ENV BACKUP_FREQUENCY="60"
ENV DISABLE_SENTRY="false"
ENV USE_AOT_CACHE="true"
ENV EXTRA_ARGS=""

# Auto-download configuration
ENV AUTO_UPDATE="false"
ENV PATCHLINE="release"
ENV CREDENTIALS_PATH=""
ENV SKIP_DOWNLOADER_UPDATE_CHECK="false"

# Entrypoint script for flexible configuration
COPY --chown=hytale:hytale entrypoint.sh /opt/hytale/entrypoint.sh
RUN chmod +x /opt/hytale/entrypoint.sh

ENTRYPOINT ["/opt/hytale/entrypoint.sh"]
