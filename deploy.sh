#!/bin/sh
# pisbx deploy: set up pisbx on a remote host from this checkout.
#
# Usage:
#   ./deploy.sh <host>        # or: make deploy HOST=<host>
#
# Copies your pi credentials (auth.json, settings.json, and models.json if you
# have one) to ~/.config/pisbx on the host, copies this checkout to ~/pisbx
# there and runs install.sh, which builds the image and installs the launcher.
# Safe to re-run. API keys for custom providers belong in auth.json, so they
# are deployed along with it.
#
# Environment variables (all optional):
#   PISBX_AUTH      local auth.json to deploy     (default: ~/.pi/agent/auth.json)
#   PISBX_SETTINGS  local settings.json to deploy (default: ~/.pi/agent/settings.json)
#   PISBX_MODELS    local models.json to deploy, skipped if absent
#                   (default: ~/.pi/agent/models.json)
#   PISBX_DEST      checkout directory on the host, relative to its home (default: pisbx)
#
# One-time prerequisites on the host (not done here, they need a password or
# a new login): docker installed, your user in the docker group, and a fresh
# login after the first install so ~/.local/bin ends up on PATH.

set -eu

say() { printf '==> %s\n' "$*"; }
die() {
  printf 'pisbx deploy: error: %s\n' "$*" >&2
  exit 1
}

host=${1:-}
[ -n "${host}" ] || die "usage: $0 <host>"

src=$(cd "$(dirname "$0")" && pwd)
auth=${PISBX_AUTH:-$HOME/.pi/agent/auth.json}
settings=${PISBX_SETTINGS:-$HOME/.pi/agent/settings.json}
models=${PISBX_MODELS:-$HOME/.pi/agent/models.json}
dest=${PISBX_DEST:-pisbx}

[ -f "${src}/install.sh" ] && [ -f "${src}/Dockerfile.pi" ] ||
  die "${src} does not look like a pisbx checkout"
[ -f "${auth}" ] || die "${auth} not found (set PISBX_AUTH)"
[ -f "${settings}" ] || die "${settings} not found (set PISBX_SETTINGS)"
command -v rsync >/dev/null 2>&1 || die "rsync is required locally"

say "copying credentials to ${host}:~/.config/pisbx"
ssh "${host}" 'mkdir -p ~/.config/pisbx && chmod 700 ~/.config/pisbx'
# -L: copy the file a symlink points to (e.g. settings.json managed by a
# dotfiles repo), not the symlink itself, which would dangle on the host.
rsync -aL --chmod=F600 "${auth}" "${host}:.config/pisbx/auth.json"
rsync -aL --chmod=F600 "${settings}" "${host}:.config/pisbx/settings.json"
if [ -f "${models}" ]; then
  rsync -aL --chmod=F600 "${models}" "${host}:.config/pisbx/models.json"
fi

say "copying checkout to ${host}:~/${dest}"
rsync -a --delete --exclude .git "${src}/" "${host}:${dest}/"

say "running install.sh on ${host}"
ssh "${host}" "cd ~/${dest} && sh ./install.sh"
