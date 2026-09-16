# Authenticated GOST Relay example

This example demonstrates an authenticated GOST v3 Relay connection using two independent containers:

- `gost-server` — GOST Relay server;
- `gost-client` — local SOCKS5 proxy that connects through the Relay server.

The example is intentionally independent of WARP and HAProxy.

## Architecture

```text
Application
    |
    | SOCKS5
    v
127.0.0.1:1080
    |
    v
GOST client
    |
    | authenticated GOST Relay
    v
GOST server :8420
    |
    v
Destination
```

The Relay server is reachable only inside the Docker Compose network.

Only the SOCKS5 listener is published on the host:

```text
127.0.0.1:1080
```

## Files

### `compose.example.yaml`

Docker Compose example that starts both the Relay server and the SOCKS5 client.

### `gost.server-example.yaml`

Configuration for the GOST Relay server.

The server authenticates clients using the user database mounted from:

```text
/run/secrets/server-users
```

### `gost.client-example.yaml`

Configuration for the local SOCKS5 client and its Relay chain.

The client reads its Relay credentials from:

```text
/run/secrets/client-credentials
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

## Start

From the `relay-auth` directory:

```bash
docker compose -f compose.example.yaml up -d
```

Check container status:

```bash
docker compose -f compose.example.yaml ps
```

Check logs:

```bash
docker compose -f compose.example.yaml logs
```

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
  -> GOST server
  -> destination
```

## Authentication test

To verify that authentication is actually enforced, temporarily change the password in:

```text
client-credentials.example
```

so it no longer matches the corresponding entry in:

```text
server-users.example
```

Then restart the client:

```bash
docker compose -f compose.example.yaml restart gost-client
```

Connections through `127.0.0.1:1080` should fail.

Restore the matching credentials afterwards.

## UDP

The GOST Relay protocol can transport UDP as well as TCP.

This first example focuses on validating:

- container startup;
- file-based authentication;
- the Relay connection;
- SOCKS5 TCP forwarding.

UDP forwarding can be tested separately after the basic Relay path is confirmed.

## Security

The included credentials:

```text
demo- change-me-now
```

are examples only.

Do not use them in a real deployment.

For production deployments:

- keep `server-users` outside the repository;
- keep `client-credentials` outside the repository;
- mount them into the container as secrets or read-only files;
- use different credentials for different clients.

For example, a server may contain:

```text
linker some-long-random-password
cottage another-long-random-password
wh13 another-long-random-password
```

while the `linker` client would receive only its own credential:

```text
linker some-long-random-password
```

## Stop

```bash
docker compose -f compose.example.yaml down
```
