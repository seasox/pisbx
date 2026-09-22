# pisbx

<p align="center">
  <img src="pisbx.png" alt="pisbx logo" width="200">
</p>

Run the [pi coding agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) inside a Docker sandbox.

`pisbx` launches `pi` in an ephemeral container with the pi agent state persisted in a Docker volume, your credentials mounted read-only, and your current directory mounted at `/workspace`.

## Requirements

- Docker
- `curl` or `wget` (for the one-line install; not needed when installing from a checkout)

## Install

One line:

```sh
curl -fsSL https://git.uni-luebeck.de/jeremyboy/pisbx/-/raw/main/install.sh | bash
```

or with wget:

```sh
wget -qO- https://git.uni-luebeck.de/jeremyboy/pisbx/-/raw/main/install.sh | bash
```

The installer downloads the launcher and the `Dockerfile.pi`, builds the `pi-sandbox` image, and installs the `pisbx` launcher to `~/.local/bin` (or `/usr/local/bin` when run as root). If that directory is not on your `PATH`, it tells you how to fix that.

The one-liner needs the repository to be publicly readable. For a private repository, pass a GitLab access token instead (note that the token ends up in your shell history and process list):

```sh
curl -fsSL https://git.uni-luebeck.de/jeremyboy/pisbx/-/raw/main/install.sh | PISBX_TOKEN=<gitlab-access-token> bash
```

Alternatively, install from a checkout — the installer then uses the local files:

```sh
git clone https://git.uni-luebeck.de/jeremyboy/pisbx.git
cd pisbx
./install.sh            # or: make install
```

### Installer options

All optional, passed as environment variables, e.g. `curl -fsSL <url> | INSTALLDIR=~/bin bash`:

| Variable          | Default                                  | Effect                                                       |
| ----------------- | ---------------------------------------- | ------------------------------------------------------------ |
| `INSTALLDIR`      | `~/.local/bin`, `/usr/local/bin` as root | Where the `pisbx` launcher is installed                      |
| `PISBX_SKIP_BUILD`| unset                                    | `1` skips building the Docker image                          |
| `PISBX_NOCACHE`   | unset                                    | `1` rebuilds the image without cache (latest `pi` release)   |
| `PISBX_TOKEN`     | unset                                    | GitLab access token, for private repositories                |
| `PISBX_REF`       | `main`                                   | Git ref to install from                                      |
| `PISBX_SRC`       | unset                                    | Install from this directory instead of downloading           |

`make install` from a checkout forwards `INSTALLDIR` if set, e.g. `make install INSTALLDIR=~/.local/bin`.

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

## Updating

- **Launcher**: re-run the install command; re-installing over an existing install is safe.
- **Image**: Docker's layer cache keeps the old `pi` version on a plain rebuild. To pick up the latest release:

  ```sh
  curl -fsSL https://git.uni-luebeck.de/jeremyboy/pisbx/-/raw/main/install.sh | PISBX_NOCACHE=1 bash
  ```

  or from a checkout: `make refresh`.

## Uninstall

```sh
rm "$(command -v pisbx)"
docker rmi pi-sandbox
docker volume ls -q --filter name=pisbx- | xargs -r docker volume rm   # optional: agent-state volumes
```

## How it works

- **Image**: built from `Dockerfile.pi` (node:24-bookworm-slim with `pi` installed globally, plus git and ripgrep). The image entrypoint is `pi`.
- **Agent state**: a Docker volume mounted at `/root/.pi` persists sessions and agent data across runs. Each project directory gets its own volume (`pisbx-<md5 of the workspace path>`), so history doesn't leak between projects; volumes start empty, so anything `pi` installs at runtime (e.g. skills) is per-project too. Set `PISBX_VOLUME` to override the name (e.g. `PISBX_VOLUME=pisbx` for a single shared volume). Docker never garbage-collects volumes — list them with `docker volume ls --filter name=pisbx-` and remove stale ones with `docker volume rm`.
- **Credentials**: `~/.config/pisbx/auth.json` and `settings.json` are required. `pisbx` refuses to start if either is missing — a missing source file would otherwise make docker create a *directory* in its place and break the mount. Copy them from an existing pi setup: `cp ~/.pi/agent/auth.json ~/.pi/agent/settings.json ~/.config/pisbx/`. Both files are mounted read-only into the container.
- **Workspace**: your current directory is bind-mounted at `/workspace` (the container's workdir). Only files under `$PWD` are visible to the agent.
