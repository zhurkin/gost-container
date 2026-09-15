# gost-container

Minimal container image for [GOST v3](https://github.com/go-gost/gost).

## Goals

- Minimal runtime image
- Pinned upstream GOST version
- Verified upstream release checksum
- Reproducible builds
- No assumptions about the surrounding network topology
- Suitable for standalone use or sharing a network namespace with other containers

## Architecture

The image itself is topology-independent.

Network namespace sharing, HAProxy integration, WARP integration, and other
deployment-specific configurations belong to Docker Compose or the surrounding
orchestration layer.

## Status

Early development.
