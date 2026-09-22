#!/bin/sh
# pisbx installer — run the pi coding agent inside a Docker sandbox.
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/seasox/pisbx/refs/heads/main/install.sh | bash
# or:
#   wget -qO- https://raw.githubusercontent.com/seasox/pisbx/refs/heads/main/install.sh | bash
#
# Environment variables (all optional):
#   INSTALLDIR        target directory for the pisbx launcher
#                     (default: ~/.local/bin, or /usr/local/bin when run as root)
#   PISBX_SKIP_BUILD  set to 1 to skip building the pi-sandbox image
#   PISBX_NOCACHE     set to 1 to rebuild the image without cache (latest pi)
#   PISBX_TOKEN       GitLab access token, for private repositories
#   PISBX_REF         git ref to install from (default: main)
#   PISBX_SRC         install from this directory instead of downloading
#
# When run from inside a repository checkout, the local files are used.

set -eu

REPO="${PISBX_REPO:-https://github.com/seasox/pisbx}"
REF="${PISBX_REF:-main}"
RAW_BASE="${REPO}/refs/heads/${REF}"

say() { printf '==> %s\n' "$*"; }
die() {
  printf 'pisbx: error: %s\n' "$*" >&2
  exit 1
}

[ -n "${HOME:-}" ] || die "HOME is not set"
command -v docker >/dev/null 2>&1 ||
  die "docker is required but was not found - see https://docs.docker.com/get-docker/"

# fetch <url> <dest>: download with curl or wget, authenticated if PISBX_TOKEN is set.
fetch() {
  if command -v curl >/dev/null 2>&1; then
    if [ -n "${PISBX_TOKEN:-}" ]; then
      curl -fsSL -H "PRIVATE-TOKEN: ${PISBX_TOKEN}" "$1" -o "$2"
    else
      curl -fsSL "$1" -o "$2"
    fi
  elif command -v wget >/dev/null 2>&1; then
    if [ -n "${PISBX_TOKEN:-}" ]; then
      wget -q --header "PRIVATE-TOKEN: ${PISBX_TOKEN}" "$1" -O "$2"
    else
      wget -q "$1" -O "$2"
    fi
  else
    die "neither curl nor wget is available - install one, or clone the repository and run ./install.sh there"
  fi
}

# GitLab answers anonymous requests to private repositories with an HTML
# sign-in page *and HTTP 200*, so curl -f does not catch it. Check the payload.
reject_html() {
  if head -n 1 "$1" | grep -qiE '<(!doctype|html|svg)'; then
    die "$2 came back as a GitLab HTML page, not the real file - ${REPO} is private or unreachable.
     Either make the project public (Settings > General > Visibility) or install with a token:
       curl -fsSL ${RAW_BASE}/install.sh | PISBX_TOKEN=<gitlab-access-token> bash"
  fi
}

# --- locate the source files -------------------------------------------------
# Precedence: PISBX_SRC > files next to this script (repository checkout) > download.

self_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || self_dir=""

srcdir=""
if [ -n "${PISBX_SRC:-}" ]; then
  if [ -f "${PISBX_SRC}/pisbx.sh" ] && [ -f "${PISBX_SRC}/Dockerfile.pi" ]; then
    srcdir="${PISBX_SRC}"
  else
    die "PISBX_SRC=${PISBX_SRC} does not contain pisbx.sh and Dockerfile.pi"
  fi
elif [ -n "${self_dir}" ] && [ -f "${self_dir}/pisbx.sh" ] && [ -f "${self_dir}/Dockerfile.pi" ]; then
  srcdir="${self_dir}"
  say "installing from checkout at ${srcdir}"
else
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir}"' EXIT HUP INT TERM
  say "downloading pisbx from ${RAW_BASE}"
  fetch "${RAW_BASE}/pisbx.sh" "${tmpdir}/pisbx.sh" ||
    die "could not download ${RAW_BASE}/pisbx.sh (does the ref '${REF}' exist?)"
  fetch "${RAW_BASE}/Dockerfile.pi" "${tmpdir}/Dockerfile.pi" ||
    die "could not download ${RAW_BASE}/Dockerfile.pi"
  reject_html "${tmpdir}/pisbx.sh" "pisbx.sh"
  reject_html "${tmpdir}/Dockerfile.pi" "Dockerfile.pi"
  head -c 2 "${tmpdir}/pisbx.sh" | grep -q '#!' ||
    die "downloaded pisbx.sh does not look like a shell script"
  head -n 1 "${tmpdir}/Dockerfile.pi" | grep -q '^FROM' ||
    die "downloaded Dockerfile.pi does not look like a Dockerfile"
  srcdir="${tmpdir}"
fi

# --- build the image ---------------------------------------------------------

if [ "${PISBX_SKIP_BUILD:-0}" = "1" ]; then
  say "PISBX_SKIP_BUILD=1 - skipping the image build"
else
  docker info >/dev/null 2>&1 ||
    die "docker is installed but the daemon is not reachable - is it running? (on Linux, your user may need to be in the docker group)"
  if [ "${PISBX_NOCACHE:-0}" = "1" ]; then
    say "PISBX_NOCACHE=1 - rebuilding the image without cache (picks up the latest pi release)"
    docker build --pull --no-cache -t pi-sandbox -f "${srcdir}/Dockerfile.pi" "${srcdir}"
  else
    say "building the pi-sandbox image (the first build takes a few minutes)"
    docker build -t pi-sandbox -f "${srcdir}/Dockerfile.pi" "${srcdir}"
  fi
fi

# --- install the launcher ----------------------------------------------------

if [ -n "${INSTALLDIR:-}" ]; then
  :
elif [ "$(id -u)" = "0" ]; then
  INSTALLDIR=/usr/local/bin
else
  INSTALLDIR="${HOME}/.local/bin"
fi
case "${INSTALLDIR}" in
/*) ;;
*) INSTALLDIR="$(pwd)/${INSTALLDIR}" ;;
esac

mkdir -p "${INSTALLDIR}" || die "cannot create ${INSTALLDIR} - set INSTALLDIR to a writable directory"
cp "${srcdir}/pisbx.sh" "${INSTALLDIR}/pisbx"
chmod 0755 "${INSTALLDIR}/pisbx"
say "installed ${INSTALLDIR}/pisbx"

case ":${PATH}:" in
*":${INSTALLDIR}:"*) ;;
*)
  say "note: ${INSTALLDIR} is not in your PATH"
  say "  fix: export PATH=\"${INSTALLDIR}:\$PATH\"  (e.g. in ~/.bashrc)"
  ;;
esac

confdir="${HOME}/.config/pisbx"
if [ -f "${confdir}/auth.json" ] && [ -f "${confdir}/settings.json" ]; then
  say "credentials found in ${confdir}"
elif [ -f "${HOME}/.pi/agent/auth.json" ] && [ -f "${HOME}/.pi/agent/settings.json" ]; then
  say "one more step - copy your pi credentials into place:"
  say "  mkdir -p '${confdir}' && cp '${HOME}/.pi/agent/auth.json' '${HOME}/.pi/agent/settings.json' '${confdir}/'"
else
  say "one more step - pisbx needs ${confdir}/auth.json and ${confdir}/settings.json (see the README)"
fi

say "done - run 'pisbx' from a project directory"
