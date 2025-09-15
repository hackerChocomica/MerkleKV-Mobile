#!/bin/bash
set -e

# Convert PEM certificates to PKCS12 format for HiveMQ
CERT_DIR="/workspaces/MerkleKV-Mobile/test/integration/certs"

echo "Converting certificates to PKCS12 format for HiveMQ..."

# Ensure certificate directory exists
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Convert CA certificate to PKCS12
openssl pkcs12 -export -out ca.p12 -nokeys -in ca.crt -passout pass:hivemq

# Convert server certificate and key to PKCS12
openssl pkcs12 -export -out server.p12 -inkey server.key -in server.crt -certfile ca.crt -passout pass:hivemq

# Convert client certificates to PKCS12 for testing
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt -passout pass:hivemq
openssl pkcs12 -export -out client2.p12 -inkey client2.key -in client2.crt -certfile ca.crt -passout pass:hivemq

echo "PKCS12 certificates generated successfully:"
echo "  CA: ca.p12"
echo "  Server: server.p12"
echo "  Client: client.p12, client2.p12"