#!/bin/sh

PI_AGENT_HOME="$HOME/.config/pisbx"
EXTRA_ARGS="${EXTRA_ARGS:-}"
PROJECT_ID="$(printf %s "$PWD" | md5sum | cut -c1-12)"
PISBX_VOLUME="${PISBX_VOLUME:-pisbx-${PROJECT_ID}}"
BASE_IMAGE="pi-sandbox"
OVERLAY="$PWD/Dockerfile.pisbx"

mkdir -p "${PI_AGENT_HOME}"

for f in auth.json settings.json; do
  if [ ! -f "${PI_AGENT_HOME}/${f}" ]; then
    echo "pisbx: error: ${PI_AGENT_HOME}/${f} is missing or not a regular file" >&2
    echo "pisbx: copy it from ~/.pi/agent/${f} and re-run" >&2
    exit 1
  fi
done

# Project overlay: a Dockerfile.pisbx in the project directory is built on top
# of the base image and run instead of it. Without a FROM line, the file is just
# a list of instructions and "FROM pi-sandbox" is prepended. The image is only
# rebuilt when the overlay or the base image changes (or PISBX_REBUILD=1).
IMAGE="${BASE_IMAGE}"
if [ -f "${OVERLAY}" ]; then
  base_id=$(docker image inspect -f '{{.Id}}' "${BASE_IMAGE}" 2>/dev/null) || {
    echo "pisbx: error: base image ${BASE_IMAGE} not found - build it first (see the README)" >&2
    exit 1
  }
  IMAGE="pi-sandbox-overlay:${PROJECT_ID}"
  overlay_hash=$({ echo "${base_id}"; cat "${OVERLAY}"; } | md5sum | cut -d' ' -f1)
  built_hash=$(docker image inspect -f '{{ index .Config.Labels "pisbx.overlay" }}' "${IMAGE}" 2>/dev/null)

  if [ "${PISBX_REBUILD:-0}" = "1" ] || [ "${overlay_hash}" != "${built_hash}" ]; then
    echo "pisbx: building ${IMAGE} from ${OVERLAY}" >&2
    if grep -qiE '^[[:space:]]*FROM[[:space:]]' "${OVERLAY}"; then
      docker build --label "pisbx.overlay=${overlay_hash}" -t "${IMAGE}" -f "${OVERLAY}" "$PWD"
    else
      { echo "FROM ${BASE_IMAGE}"; cat "${OVERLAY}"; } |
        docker build --label "pisbx.overlay=${overlay_hash}" -t "${IMAGE}" -f - "$PWD"
    fi || {
      echo "pisbx: error: building ${OVERLAY} failed" >&2
      exit 1
    }
  fi
fi

# shellcheck disable=SC2086  # EXTRA_ARGS is intentionally word-split
exec docker run --rm -it \
  --mount type=volume,src="${PISBX_VOLUME}",dst=/root/.pi \
  -v "$PWD:/workspace" \
  -v "${PI_AGENT_HOME}/auth.json:/root/.pi/agent/auth.json:ro" \
  -v "${PI_AGENT_HOME}/settings.json:/root/.pi/agent/settings.json:ro" \
  ${EXTRA_ARGS} "${IMAGE}" "$@"
