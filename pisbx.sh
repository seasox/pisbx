#!/bin/sh

PI_AGENT_HOME="$HOME/.config/pisbx"
EXTRA_ARGS="${EXTRA_ARGS:-}"
ENTRYPOINT=""

mkdir -p "${PI_AGENT_HOME}"

while [ $# -gt 0 ]; do
  case "$1" in
    --entrypoint)
      [ $# -ge 2 ] || { echo "pisbx: --entrypoint requires a value" >&2; exit 1; }
      ENTRYPOINT="$2"
      shift 2
      ;;
    --entrypoint=*)
      ENTRYPOINT="${1#--entrypoint=}"
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [ -n "${ENTRYPOINT}" ]; then
  EXTRA_ARGS="${EXTRA_ARGS} --entrypoint=${ENTRYPOINT}"
fi

exec docker run --rm -it \
  --mount type=volume,src=pisbx,dst=/root/.pi/agent \
  -v "$PWD:/workspace" \
  -v "${PI_AGENT_HOME}/auth.json:/root/.pi/agent/auth.json:ro" \
  -v "${PI_AGENT_HOME}/settings.json:/root/.pi/agent/settings.json:ro" \
  ${EXTRA_ARGS} pi-sandbox "$@"
