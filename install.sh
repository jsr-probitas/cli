#!/bin/sh
# Install script for @probitas/cli
#
# Usage:
#   curl -fsSL https://jsr.io/@probitas/cli/install.sh | sh
#   curl -fsSL https://jsr.io/@probitas/cli/install.sh | PROBITAS_VERSION=0.1.0 sh
#
# Environment variables:
#   PROBITAS_VERSION      Specify the version to install (default: latest)
#   PROBITAS_INSTALL_DIR  Specify the installation directory (default: ~/.deno/bin)

set -e

# Check if deno is available
if ! command -v deno >/dev/null 2>&1; then
  echo "Error: deno is not installed"
  echo "Please install Deno first: https://deno.land/"
  exit 1
fi

PACKAGE_NAME="@probitas/cli"
COMMAND_NAME="probitas"
JSR_BASE_URL="https://jsr.io/@probitas/cli"

# Read configuration from environment variables
VERSION="${PROBITAS_VERSION:-}"
INSTALL_DIR="${PROBITAS_INSTALL_DIR:-}"

# Fetch the latest version from JSR if not specified
if [ -z "$VERSION" ]; then
  echo "Fetching latest version..."
  # JSR provides a meta.json file with version information
  VERSION=$(curl -fsSL "${JSR_BASE_URL}/meta.json" | grep -o '"latest":"[^"]*"' | cut -d'"' -f4)
  if [ -z "$VERSION" ]; then
    echo "Error: Failed to fetch latest version"
    exit 1
  fi
fi

echo "Installing ${COMMAND_NAME}@${VERSION}..."

# Create a temporary directory
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Download the deno.lock file
LOCK_URL="${JSR_BASE_URL}/${VERSION}/deno.lock"
LOCK_FILE="${TMPDIR}/deno.lock"

echo "Downloading lock file from ${LOCK_URL}..."
if ! curl -fsSL "$LOCK_URL" -o "$LOCK_FILE"; then
  echo "Error: Failed to download deno.lock from ${LOCK_URL}"
  exit 1
fi

# Build deno install command
DENO_INSTALL_ARGS="-A --global -rf --lock=$LOCK_FILE -n ${COMMAND_NAME}"

# Add custom install directory if specified
if [ -n "$INSTALL_DIR" ]; then
  DENO_INSTALL_ARGS="$DENO_INSTALL_ARGS --root=$INSTALL_DIR"
  echo "Installing to ${INSTALL_DIR}/bin..."
fi

# Install using deno with the lock file
echo "Running deno install..."
deno install $DENO_INSTALL_ARGS "jsr:${PACKAGE_NAME}@${VERSION}"

echo ""
echo "Successfully installed ${COMMAND_NAME}@${VERSION}"

# Show path hint if custom install directory was used
if [ -n "$INSTALL_DIR" ]; then
  echo ""
  echo "Make sure ${INSTALL_DIR}/bin is in your PATH:"
  echo "  export PATH=\"${INSTALL_DIR}/bin:\$PATH\""
fi
