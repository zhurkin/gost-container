#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

mkdir -p certs

rm -f \
    certs/ca.key.pem \
    certs/ca.cert.pem \
    certs/ca.cert.srl \
    certs/server.key.pem \
    certs/server.cert.pem \
    certs/server.csr.pem \
    certs/server.ext

echo "=== Generate test CA ==="

openssl req \
    -x509 \
    -newkey rsa:2048 \
    -nodes \
    -sha256 \
    -days 3650 \
    -keyout certs/ca.key.pem \
    -out certs/ca.cert.pem \
    -subj "/CN=GOST Relay Test CA"

echo
echo "=== Generate server key and CSR ==="

openssl req \
    -newkey rsa:2048 \
    -nodes \
    -sha256 \
    -keyout certs/server.key.pem \
    -out certs/server.csr.pem \
    -subj "/CN=relay.test"

cat > certs/server.ext <<'EOF'
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:relay.test
EOF

echo
echo "=== Sign server certificate ==="

openssl x509 \
    -req \
    -sha256 \
    -days 825 \
    -in certs/server.csr.pem \
    -CA certs/ca.cert.pem \
    -CAkey certs/ca.key.pem \
    -CAcreateserial \
    -out certs/server.cert.pem \
    -extfile certs/server.ext

rm -f \
    certs/server.csr.pem \
    certs/server.ext \
    certs/ca.cert.srl

chmod 0600 \
    certs/ca.key.pem \
    certs/server.key.pem

chmod 0644 \
    certs/ca.cert.pem \
    certs/server.cert.pem

echo
echo "=== Verify certificate ==="

openssl verify \
    -CAfile certs/ca.cert.pem \
    certs/server.cert.pem

echo
echo "=== Server certificate ==="

openssl x509 \
    -in certs/server.cert.pem \
    -noout \
    -subject \
    -issuer \
    -ext subjectAltName

echo
echo "TLS test certificates generated."
