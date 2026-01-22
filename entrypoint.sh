#!/bin/bash
set -e

DOWNLOAD_DIR="/opt/hytale/downloads"
SERVER_FILES_DIR="/opt/hytale/server-files"
DEFAULT_CREDENTIALS_PATH="/opt/hytale/config/credentials.json"

# Function to check if server files exist
check_server_files() {
    if [ -f "HytaleServer.jar" ] && [ -f "Assets.zip" ]; then
        return 0
    fi
    return 1
}

# Function to download server files using hytale-downloader
download_server_files() {
    echo "=================================================="
    echo "HYTALE SERVER DOWNLOAD"
    echo "=================================================="

    # Check if hytale-downloader exists
    if [ ! -f "/opt/hytale/hytale-downloader" ]; then
        echo "Error: hytale-downloader not found!"
        echo "Please either:"
        echo "  1. Rebuild the image with the correct HYTALE_DOWNLOADER_URL"
        echo "  2. Manually copy server files to the server/ directory"
        exit 1
    fi

    echo "Downloading Hytale server files..."
    echo ""

    # Build downloader arguments
    DOWNLOADER_ARGS="-download-path ${DOWNLOAD_DIR}/game.zip"

    # Add credentials path if specified or if default exists
    if [ -n "${CREDENTIALS_PATH}" ]; then
        DOWNLOADER_ARGS="${DOWNLOADER_ARGS} -credentials-path ${CREDENTIALS_PATH}"
        echo "Using credentials file: ${CREDENTIALS_PATH}"
    elif [ -f "${DEFAULT_CREDENTIALS_PATH}" ]; then
        DOWNLOADER_ARGS="${DOWNLOADER_ARGS} -credentials-path ${DEFAULT_CREDENTIALS_PATH}"
        echo "Using credentials file: ${DEFAULT_CREDENTIALS_PATH}"
    else
        echo "No credentials file found. Interactive OAuth2 authentication required."
    fi

    # Add patchline
    if [ -n "${PATCHLINE}" ] && [ "${PATCHLINE}" != "release" ]; then
        DOWNLOADER_ARGS="${DOWNLOADER_ARGS} -patchline ${PATCHLINE}"
        echo "Using patchline: ${PATCHLINE}"
    fi

    # Skip update check if requested
    if [ "${SKIP_DOWNLOADER_UPDATE_CHECK}" = "true" ]; then
        DOWNLOADER_ARGS="${DOWNLOADER_ARGS} -skip-update-check"
    fi

    echo ""

    # Run the downloader
    /opt/hytale/hytale-downloader ${DOWNLOADER_ARGS}

    # Extract the downloaded files
    if [ -f "${DOWNLOAD_DIR}/game.zip" ]; then
        echo "Extracting server files..."
        unzip -o "${DOWNLOAD_DIR}/game.zip" -d "${DOWNLOAD_DIR}/extracted"

        # Copy server files to working directory
        if [ -d "${DOWNLOAD_DIR}/extracted/Server" ]; then
            cp -r "${DOWNLOAD_DIR}/extracted/Server/"* /opt/hytale/
            echo "Server files extracted successfully"
        fi

        if [ -f "${DOWNLOAD_DIR}/extracted/Assets.zip" ]; then
            cp "${DOWNLOAD_DIR}/extracted/Assets.zip" /opt/hytale/
            echo "Assets.zip copied successfully"
        fi

        # Clean up
        rm -rf "${DOWNLOAD_DIR}/extracted"
        echo "Download complete!"
    else
        echo "Error: Download failed - game.zip not found"
        exit 1
    fi
}

# Function to copy pre-packaged server files
copy_server_files() {
    if [ -d "${SERVER_FILES_DIR}" ] && [ "$(ls -A ${SERVER_FILES_DIR} 2>/dev/null)" ]; then
        echo "Copying pre-packaged server files..."
        cp -rn "${SERVER_FILES_DIR}/"* /opt/hytale/ 2>/dev/null || true
    fi
}

# Function to check for updates
check_for_updates() {
    if [ -f "/opt/hytale/hytale-downloader" ]; then
        echo "Checking for server updates..."
        CURRENT_VERSION=$(/opt/hytale/hytale-downloader -print-version 2>/dev/null || echo "unknown")
        echo "Current game version: ${CURRENT_VERSION}"
    fi
}

echo "=================================================="
echo "HYTALE SERVER STARTUP"
echo "=================================================="

# Try to copy any pre-packaged server files first
copy_server_files

# Check if server files exist
if ! check_server_files; then
    echo "Server files not found. Attempting to download..."
    download_server_files
fi

# Verify files exist after download attempt
if ! check_server_files; then
    echo "Error: Server files still not found after download!"
    echo "Required files: HytaleServer.jar, Assets.zip"
    echo ""
    echo "Options:"
    echo "  1. Run with docker compose run --rm hytale-server to complete OAuth"
    echo "  2. Manually copy server files to the server/ directory and rebuild"
    exit 1
fi

# Check for updates if enabled
if [ "${AUTO_UPDATE}" = "true" ]; then
    check_for_updates
fi

# Build Java arguments
JAVA_ARGS="-Xms${JAVA_MIN_HEAP} -Xmx${JAVA_MAX_HEAP}"

# Add AOT cache if enabled and file exists
if [ "${USE_AOT_CACHE}" = "true" ] && [ -f "HytaleServer.aot" ]; then
    JAVA_ARGS="${JAVA_ARGS} -XX:AOTCache=HytaleServer.aot"
    echo "Using AOT cache for faster startup"
fi

# Build server arguments
SERVER_ARGS="--assets Assets.zip --bind 0.0.0.0:${SERVER_PORT}"

# Add authentication mode
SERVER_ARGS="${SERVER_ARGS} --auth-mode ${AUTH_MODE}"

# Add backup configuration if enabled
if [ "${ENABLE_BACKUP}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} --backup --backup-dir /opt/hytale/backups --backup-frequency ${BACKUP_FREQUENCY}"
    echo "Backups enabled: every ${BACKUP_FREQUENCY} minutes to /opt/hytale/backups"
fi

# Disable Sentry if requested (recommended for development)
if [ "${DISABLE_SENTRY}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} --disable-sentry"
    echo "Sentry crash reporting disabled"
fi

# Add any extra arguments
if [ -n "${EXTRA_ARGS}" ]; then
    SERVER_ARGS="${SERVER_ARGS} ${EXTRA_ARGS}"
fi

echo ""
echo "Starting Hytale Server..."
echo "Java args: ${JAVA_ARGS}"
echo "Server args: ${SERVER_ARGS}"
echo "=================================================="

# Start the server
exec java ${JAVA_ARGS} -jar HytaleServer.jar ${SERVER_ARGS}
