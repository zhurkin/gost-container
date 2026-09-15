#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

debian_image="$(jq -r '.debian.image' versions.json)"
debian_suite="$(jq -r '.debian.suite' versions.json)"

gost_version="$(jq -r '.gost.version' versions.json)"
gost_os="$(jq -r '.gost.os' versions.json)"
gost_arch="$(jq -r '.gost.arch' versions.json)"
gost_sha256="$(jq -r '.gost.sha256' versions.json)"

for value in \
    debian_image \
    debian_suite \
    gost_version \
    gost_os \
    gost_arch \
    gost_sha256
do
    if [[ -z "${!value}" || "${!value}" == "null" ]]; then
        echo "ERROR: ${value} is not defined in versions.json" >&2
        exit 1
    fi
done

sed \
    -e "s|%%DEBIAN_IMAGE%%|${debian_image}|g" \
    -e "s|%%DEBIAN_SUITE%%|${debian_suite}|g" \
    -e "s|%%GOST_VERSION%%|${gost_version}|g" \
    -e "s|%%GOST_OS%%|${gost_os}|g" \
    -e "s|%%GOST_ARCH%%|${gost_arch}|g" \
    -e "s|%%GOST_SHA256%%|${gost_sha256}|g" \
    Dockerfile.template > Dockerfile

if grep -q '%%[A-Z0-9_]*%%' Dockerfile; then
    echo "ERROR: unresolved template variables remain in Dockerfile" >&2
    grep -n '%%[A-Z0-9_]*%%' Dockerfile >&2 || true
    exit 1
fi

echo "Generated Dockerfile"
echo "  Debian: debian:${debian_image}"
echo "  GOST:   ${gost_version}"
echo "  OS:     ${gost_os}"
echo "  Arch:   ${gost_arch}"
