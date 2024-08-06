#!/bin/bash
set -e -o pipefail

if command -v zola >/dev/null; then
    echo "Zola is already installed!"
    exit 0
fi

echo "Installing Zola..."

# Check if curl is installed
if ! command -v curl >/dev/null; then
    echo "Error: curl is not installed. Please install curl and try again."
    exit 1
fi
# Check if unzip is installed
if ! command -v tar >/dev/null; then
    echo "Error: tar is not installed. Please install tar and try again."
    exit 1
fi

# Determine arch
ARCH=$(uname -m)
# Set the download URL based on the platform and architecture
if [ "$ARCH" != "x86_64" ]; then
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

# Determine the latest version of Zola
ZOLA_LATEST_VERSION=$(curl -s https://api.github.com/repos/getzola/zola/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
ZOLA_VERSION=${LATEST_VERSION-$ZOLA_LATEST_VERSION}
ZOLA_DOWNLOAD_URL="https://github.com/getzola/zola/releases/download/${ZOLA_VERSION}/zola-${ZOLA_VERSION}-x86_64-unknown-linux-gnu.tar.gz"

# Download and install Zola
curl -sL -o zola.tar.gz "$ZOLA_DOWNLOAD_URL"
tar -xzf zola.tar.gz

# Check if the destination directory is writable
if [ -w "/usr/local/bin" ]; then
    mv zola /usr/local/bin
else
    mkdir -p ~/.local/bin
    mv zola ~/.local/bin

fi

rm zola.tar.gz
zola --version
