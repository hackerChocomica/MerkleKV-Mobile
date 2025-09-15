#!/bin/bash
set -e

# Certificate generation script for integration testing
# Creates CA, server, and client certificates for TLS testing

CERT_DIR="/workspaces/MerkleKV-Mobile/test/integration/certs"
VALIDITY_DAYS=365

echo "Generating TLS certificates for integration testing..."

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate
openssl req -new -x509 -key ca.key -sha256 -subj "/C=US/ST=Test/L=Test/O=MerkleKV/OU=Testing/CN=Test-CA" -days $VALIDITY_DAYS -out ca.crt

# Generate server private key
openssl genrsa -out server.key 4096

# Create server certificate signing request
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=Test/L=Test/O=MerkleKV/OU=Testing/CN=localhost"

# Create server certificate extensions file
cat > server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = mosquitto-test
DNS.3 = hivemq-test
DNS.4 = 127.0.0.1
IP.1 = 127.0.0.1
IP.2 = 172.21.0.2
IP.3 = 172.21.0.3
EOF

# Generate server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $VALIDITY_DAYS -sha256 -extfile server.ext

# Generate client private key
openssl genrsa -out client.key 4096

# Generate client certificate signing request
openssl req -new -key client.key -out client.csr -subj "/C=US/ST=Test/L=Test/O=MerkleKV/OU=Testing/CN=test-client"

# Create client certificate extensions file
cat > client.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = clientAuth
EOF

# Generate client certificate
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days $VALIDITY_DAYS -sha256 -extfile client.ext

# Generate second client for multi-client testing
openssl genrsa -out client2.key 4096
openssl req -new -key client2.key -out client2.csr -subj "/C=US/ST=Test/L=Test/O=MerkleKV/OU=Testing/CN=test-client-2"
openssl x509 -req -in client2.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client2.crt -days $VALIDITY_DAYS -sha256 -extfile client.ext

# Clean up CSR and extension files
rm -f *.csr *.ext *.srl

# Set appropriate permissions
chmod 644 *.crt
chmod 600 *.key

echo "Certificates generated successfully:"
echo "  CA Certificate: ca.crt"
echo "  Server Certificate: server.crt / server.key"
echo "  Client Certificate: client.crt / client.key"
echo "  Client 2 Certificate: client2.crt / client2.key"

# Verify certificates
echo ""
echo "Verifying certificates..."
openssl verify -CAfile ca.crt server.crt
openssl verify -CAfile ca.crt client.crt
openssl verify -CAfile ca.crt client2.crt

echo "Certificate generation complete!"