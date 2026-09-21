# pisbx

Run the [pi coding agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) inside a Docker sandbox.

`pisbx` launches `pi` in an ephemeral container with the pi agent state persisted in a Docker volume, your credentials mounted read-only, and your current directory mounted at `/workspace`.

## Requirements

- Docker
- `make` (for install)

## Install

```sh
make install        # builds the pi-sandbox image and installs pisbx to /usr/local/bin
```

Set `INSTALLDIR` to install elsewhere, e.g. `make install INSTALLDIR=~/.local/bin`.

## Usage

From any project directory:

```sh
cd ~/my-project
pisbx
```

This drops you into an interactive `pi` session in the container with your project files at `/workspace`.

Arguments are forwarded to `pi` inside the container:

```sh
pisbx -p "explain this repo"    # one-shot prompt instead of an interactive session
pisbx --version
```

Pass extra `docker run` flags via `EXTRA_ARGS`:

```sh
EXTRA_ARGS="-e FOO=bar" pisbx
```

Agent state is isolated per project by default. To share it across projects instead, set `PISBX_VOLUME`:

```sh
PISBX_VOLUME=pisbx pisbx
```

## How it works

- **Image**: built from `Dockerfile.pi` (node:24-bookworm-slim with `pi` installed globally, plus git and ripgrep). The image entrypoint is `pi`.
- **Agent state**: a Docker volume mounted at `/root/.pi/agent` persists sessions and agent data across runs. Each project directory gets its own volume (`pisbx-<md5 of the workspace path>`), so history doesn't leak between projects; volumes start empty, so anything `pi` installs at runtime (e.g. skills) is per-project too. Set `PISBX_VOLUME` to override the name (e.g. `PISBX_VOLUME=pisbx` for a single shared volume). Docker never garbage-collects volumes — list them with `docker volume ls --filter name=pisbx-` and remove stale ones with `docker volume rm`.
- **Credentials**: `~/.config/pisbx/auth.json` and `settings.json` are mounted read-only into the container. Populate them from an existing pi setup if you use custom auth settings.
- **Workspace**: your current directory is bind-mounted at `/workspace` (the container's workdir). Only files under `$PWD` are visible to the agent.
