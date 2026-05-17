#!/usr/bin/env bash

# sync-zizmor-versions.sh: emit `<tag> <digest>` lines for every tag of
# zizmorcore/zizmor on GHCR. Reuses digests from the pins file passed as
# $1 when a tag already has one; `latest` is always refreshed.

set -euo pipefail

CI=${CI:-false}
IMAGE="ghcr.io/zizmorcore/zizmor"
PINS="${1:-/dev/null}"

err() {
    [[ "${CI}" = "true" ]] && echo "::error::${*}" || echo "ERROR: ${*}" >&2
}

die() {
  err "${*}"
  exit 1
}

installed() {
    command -v "${1}" >/dev/null 2>&1
}

installed skopeo || die "'skopeo' is required to continue"
installed jq || die "'jq' is required to continue"
[[ -r "${PINS}" ]] || die "pins file is not readable: ${PINS}"

lookup_digest() {
    skopeo --override-os=linux --override-arch=amd64 inspect \
        "docker://${IMAGE}:${1}" | jq -r '.Digest'
}

lookup_pinned_digest() {
    awk -v tag="${1}" '$1 == tag { print $2; exit }' "${PINS}"
}

# For each tag, reuse an existing digest when possible. New tags and `latest`
# are resolved with `skopeo inspect` and emitted as:
# <tag> <digest>
skopeo list-tags "docker://${IMAGE}" | jq -r '.Tags[]' |
while IFS= read -r tag; do
    digest=""

    if [[ "${tag}" != "latest" ]]; then
        digest=$(lookup_pinned_digest "${tag}")
    fi

    if [[ -z "${digest}" ]]; then
        digest=$(lookup_digest "${tag}")
    fi

    echo "${tag} ${digest}"
done
