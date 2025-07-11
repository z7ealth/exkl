#!/usr/bin/env bash
set -euo pipefail

APP_NAME="exkl"
ENV="prod"
RELEASE_DIR="_build/$ENV/rel/$APP_NAME"
NIFS_DIR="priv/nifs"

log() {
  echo "[+] $1"
}

# Check for required commands
command -v mix &>/dev/null || {
  echo "Error: mix command not found. Please install Elixir and Erlang: https://elixir-lang.org/"
  exit 1
}

command -v gcc &>/dev/null || {
  echo "Error: gcc command not found."
  exit 1
}

if [ ! -d "$NIFS_DIR" ]; then
  mkdir -p "$NIFS_DIR"
  echo "Created directory: $NIFS_DIR"
else
  echo "Directory already exists: $NIFS_DIR"
fi

# Compile NIFs
gcc -fPIC -shared -I/usr/lib/erlang/usr/include c_src/sensors_nif.c -o priv/nifs/sensors_nif.so -lsensors
gcc -fPIC -shared -I/usr/lib/erlang/usr/include -I/usr/include/hidapi c_src/hid_api_nif.c -o priv/nifs/hid_api_nif.so -lhidapi-hidraw

# Build elixir app

log "Fetching dependencies..."
mix deps.get

# Generate or reuse SECRET_KEY_BASE
if [[ -z "${SECRET_KEY_BASE:-}" ]]; then
  log "Generating SECRET_KEY_BASE..."
  SECRET_KEY_BASE=$(mix phx.gen.secret)
fi

log "Using SECRET_KEY_BASE=${SECRET_KEY_BASE:0:8}...(hidden)"

log "Fetching production dependencies..."
MIX_ENV=$ENV mix deps.get --only prod

log "Compiling project..."
MIX_ENV=$ENV mix compile

log "Deploying assets..."
MIX_ENV=$ENV mix assets.deploy

log "Generating release configuration..."
mix phx.gen.release

log "Building release..."
MIX_ENV=$ENV mix release --overwrite

# Run app

log "Starting the release..."
PHX_SERVER=true SECRET_KEY_BASE=$SECRET_KEY_BASE "$RELEASE_DIR/bin/$APP_NAME" start
