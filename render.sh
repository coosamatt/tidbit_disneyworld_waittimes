#!/bin/bash
# Wrapper script to render tron_wait.star with proper certificate configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set SSL certificate file to use our combined CA bundle
export SSL_CERT_FILE="$SCRIPT_DIR/combined-ca-bundle.pem"

# Run pixlet render with any passed arguments
pixlet render tron_wait.star "$@"

