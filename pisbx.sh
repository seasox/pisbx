#!/bin/sh

PI_AGENT_HOME="$HOME/.config/pisbx"
EXTRA_ARGS="${EXTRA_ARGS:-}"
PISBX_VOLUME="${PISBX_VOLUME:-pisbx-$(printf %s "$PWD" | md5sum | cut -c1-12)}"

mkdir -p "${PI_AGENT_HOME}"

exec docker run --rm -it \
  --mount type=volume,src="${PISBX_VOLUME}",dst=/root/.pi/agent \
  -v "$PWD:/workspace" \
  -v "${PI_AGENT_HOME}/auth.json:/root/.pi/agent/auth.json:ro" \
  -v "${PI_AGENT_HOME}/settings.json:/root/.pi/agent/settings.json:ro" \
  ${EXTRA_ARGS} pi-sandbox "$@"
