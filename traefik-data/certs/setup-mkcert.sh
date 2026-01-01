#!/bin/bash
#
# Generate trusted SSL certificates using mkcert
# Requires: mkcert (brew install mkcert)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    echo "mkcert is not installed. Please install it first:"
    echo "  brew install mkcert"
    echo "  mkcert -install"
    exit 1
fi

# Install the local CA if not already done
mkcert -install 2>/dev/null || true

# Generate certificates for localhost domains
echo "Generating certificates for gitlab.localhost and traefik.localhost..."
mkcert -cert-file localhost.crt -key-file localhost.key \
    localhost \
    "*.localhost" \
    gitlab.localhost \
    traefik.localhost \
    127.0.0.1 \
    ::1

echo ""
echo "Certificates generated successfully!"
echo "  Certificate: $SCRIPT_DIR/localhost.crt"
echo "  Private key: $SCRIPT_DIR/localhost.key"
