#!/bin/sh

PI_AGENT_HOME="$HOME/.config/pisbx"
EXTRA_ARGS="${EXTRA_ARGS:-}"
PISBX_VOLUME="${PISBX_VOLUME:-pisbx-$(printf %s "$PWD" | md5sum | cut -c1-12)}"

mkdir -p "${PI_AGENT_HOME}"

for f in auth.json settings.json; do
  if [ ! -f "${PI_AGENT_HOME}/${f}" ]; then
    echo "pisbx: error: ${PI_AGENT_HOME}/${f} is missing or not a regular file" >&2
    echo "pisbx: copy it from ~/.pi/agent/${f} and re-run" >&2
    exit 1
  fi
done

# shellcheck disable=SC2086  # EXTRA_ARGS is intentionally word-split
exec docker run --rm -it \
  --mount type=volume,src="${PISBX_VOLUME}",dst=/root/.pi \
  -v "$PWD:/workspace" \
  -v "${PI_AGENT_HOME}/auth.json:/root/.pi/agent/auth.json:ro" \
  -v "${PI_AGENT_HOME}/settings.json:/root/.pi/agent/settings.json:ro" \
  ${EXTRA_ARGS} pi-sandbox "$@"
