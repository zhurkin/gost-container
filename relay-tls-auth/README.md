# Authenticated GOST Relay over TLS

This example demonstrates an authenticated GOST v3 Relay connection transported over TLS/TCP using two independent containers:

- `gost-server` — authenticated GOST Relay server with a TLS listener;
- `gost-client` — local SOCKS5 and UDP forwarding services that connect through the Relay server.

The example is intentionally independent of WARP and HAProxy.

## Architecture

```text
TCP application traffic ─┐
                         │
UDP application traffic ─┤
                         v
                    GOST client
                         |
                         | authenticated GOST Relay
                         | inside TLS
                         | inside TCP
                         v
                    GOST server
                         |
                  +------+------+
                  |             |
                 TCP           UDP
                  |             |
                  v             v
              Destination   Destination
```

The transport between the two GOST instances is TLS over TCP.

UDP payloads are encapsulated by GOST Relay and transported through the same TLS/TCP path.

## Files

### `compose.example.yaml`

Docker Compose example that starts both the Relay server and the client.

### `gost.server-example.yaml`

Configuration for the authenticated GOST Relay server.

The server listens on:

```text
:8443/TCP
```

using a TLS listener.

The server authenticates clients using the user database mounted from:

```text
/run/secrets/server-users
```

The TLS server certificate and private key are mounted from:

```text
/run/secrets/tls-server-cert
/run/secrets/tls-server-key
```

### `gost.client-example.yaml`

Configuration for the GOST client.

It exposes:

```text
127.0.0.1:1080/TCP
```

as a SOCKS5 proxy and:

```text
127.0.0.1:1053/UDP
```

as a UDP forwarding test service.

The client reads its Relay credentials from:

```text
/run/secrets/client-credentials
```

The client verifies the Relay server certificate using:

```text
/run/secrets/tls-ca-cert
```

The expected TLS server name is:

```text
relay.test
```

### `server-users.example`

List of users allowed to connect to the Relay server.

Format:

```text
username password
```

Example:

```text
demo- change-me-now
```

A server can contain multiple users:

```text
demo- change-me-now
user1 another-password
user2 another-password
```

### `client-credentials.example`

Credentials used by this particular GOST client when authenticating to the Relay server.

Format:

```text
username password
```

Example:

```text
demo- change-me-now
```

The username and password must match one of the entries in `server-users.example`.

### `generate-test-certs.sh`

Generates a local test CA and a server certificate for:

```text
relay.test
```

The generated files are stored in:

```text
certs/
```

The GOST container runs as UID/GID `10001`.

The generated server private key is therefore made readable by GID `10001` while remaining unavailable to other users.

The CA private key is used only to sign the test server certificate and is not mounted into either GOST container.

## Generate test certificates

Before starting the example, run:

```bash
chmod +x generate-test-certs.sh
./generate-test-certs.sh
```

The certificate verification step should report:

```text
certs/server.cert.pem: OK
```

The server certificate should contain:

```text
DNS:relay.test
```

as its Subject Alternative Name.

## Start

From the `relay-tls-auth` directory:

```bash
docker compose -f compose.example.yaml up -d
```

Check container status:

```bash
docker compose -f compose.example.yaml ps
```

Check logs:

```bash
docker compose -f compose.example.yaml logs --tail 50
```

The server should report a TLS listener on port `8443`.

## TCP test

Use the local SOCKS5 proxy:

```bash
curl \
  --socks5-hostname 127.0.0.1:1080 \
  https://www.cloudflare.com/cdn-cgi/trace
```

Or:

```bash
curl \
  --socks5-hostname 127.0.0.1:1080 \
  https://example.com/
```

The request should pass through:

```text
curl
  -> SOCKS5 127.0.0.1:1080
  -> GOST client
  -> authenticated GOST Relay
  -> TLS
  -> TCP
  -> GOST server
  -> destination
```

## UDP test

The example also exposes:

```text
127.0.0.1:1053/UDP
```

UDP traffic is forwarded through the same authenticated Relay over TLS/TCP path to:

```text
1.1.1.1:53/UDP
```

Test it with:

```bash
dig +notcp \
  @127.0.0.1 \
  -p 1053 \
  example.com
```

A successful response should contain:

```text
status: NOERROR
```

and:

```text
SERVER: 127.0.0.1#1053(127.0.0.1) (UDP)
```

This confirms the following path:

```text
UDP client
  -> GOST client
  -> authenticated GOST Relay
  -> TLS
  -> TCP
  -> GOST server
  -> UDP destination
```

## Authentication test

To verify that Relay authentication is enforced, temporarily change the password in:

```text
client-credentials.example
```

so it no longer matches the corresponding entry in:

```text
server-users.example
```

Then recreate the client:

```bash
docker compose -f compose.example.yaml up -d \
  --force-recreate gost-client
```

Connections through `127.0.0.1:1080` should fail.

The server log should report an authentication failure such as:

```text
relay: unauthorized
```

Restore the matching credentials afterwards and recreate the client again.

## TLS verification test

TLS certificate verification is enabled on the client.

The client expects:

```text
serverName: relay.test
```

Changing the expected server name to a value that is not present in the server certificate should cause the TLS connection to fail before Relay authentication succeeds.

## HAProxy

HAProxy is intentionally not part of this example.

A later deployment can place HAProxy between the GOST client and server:

```text
GOST client
    |
    | Relay / TLS / TCP
    v
HAProxy
    |
    v
GOST server
```

HAProxy only needs to handle the outer TCP/TLS connection.

TCP and UDP application payloads remain encapsulated inside the GOST Relay protocol.

## Security

The included credentials:

```text
demo- change-me-now
```

are examples only.

The generated CA and certificates are also intended only for testing.

Do not reuse these credentials, CA keys, or certificates in production.

For production deployments:

- keep `server-users` outside the repository;
- keep `client-credentials` outside the repository;
- use unique credentials for different clients;
- use production TLS certificates or a dedicated private PKI;
- mount credentials and private keys read-only;
- do not commit private keys to Git.

## Stop

```bash
docker compose -f compose.example.yaml down
```
