#!/bin/bash
# Script to set up queue-times.com certificate for pixlet

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Downloading certificate from queue-times.com..."
echo | openssl s_client -showcerts -connect queue-times.com:443 -servername queue-times.com 2>/dev/null | \
    sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > queue-times-cert.pem

if [ ! -s queue-times-cert.pem ]; then
    echo "Error: Failed to download certificate"
    exit 1
fi

echo "Certificate downloaded to queue-times-cert.pem"

# Add to macOS keychain
echo "Adding certificate to macOS keychain..."
if security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db queue-times-cert.pem 2>/dev/null; then
    echo "✓ Certificate added to keychain (login.keychain-db)"
elif security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain queue-times-cert.pem 2>/dev/null; then
    echo "✓ Certificate added to keychain (login.keychain)"
else
    echo "⚠ Warning: Could not add to keychain automatically"
    echo "  You may need to add it manually:"
    echo "  open queue-times-cert.pem"
    echo "  Then trust it in Keychain Access"
fi

# Create combined CA bundle for Go
echo "Creating combined CA bundle..."
if [ -f /etc/ssl/cert.pem ]; then
    cat /etc/ssl/cert.pem queue-times-cert.pem > combined-ca-bundle.pem
    echo "✓ Created combined-ca-bundle.pem"
elif security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > system-certs.pem 2>/dev/null; then
    cat system-certs.pem queue-times-cert.pem > combined-ca-bundle.pem
    echo "✓ Created combined-ca-bundle.pem from system certificates"
    rm -f system-certs.pem
else
    cp queue-times-cert.pem combined-ca-bundle.pem
    echo "⚠ Created combined-ca-bundle.pem (system certs not found)"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Note: If pixlet still fails with certificate errors, you may need to:"
echo "  1. Update your system certificates: brew update && brew upgrade"
echo "  2. Reinstall pixlet: brew reinstall tidbyt/tidbyt/pixlet"
echo "  3. Or patch pixlet's source code to disable cert validation"
echo ""
echo "To test, run:"
echo "  pixlet render tron_wait.star --magnify 10"

