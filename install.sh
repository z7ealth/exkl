#!/usr/bin/env bash
set -euo pipefail

APP_NAME="exkl"
ENV="prod"
RELEASE_DIR="_build/$ENV/rel/$APP_NAME"
NIFS_DIR="priv/nifs"
EXKL_DIR="$HOME/.config/exkl"
SERVICE_NAME="exkl"
SERVICE_FILE="${SERVICE_NAME}.service"
SERVICE_DIR="$HOME/.config/systemd/user"
EXEC_PATH="$HOME/.config/exkl/bin/exkl"
UDEV_RULE_FILE="/etc/udev/rules.d/99-hid.rules"
UDEV_RULE='SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", ATTRS{idProduct}=="0003", MODE="0660", GROUP="plugdev"'

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

# Check if the directory exists
if [ -d "$EXKL_DIR" ]; then
  # Directory is not empty
  echo -e "The directory $EXKL_DIR is not empty. Existing configuration will be lost.\n"
  read -p "Do you want to proceed? (y/n):" choice
  case "$choice" in
    y|Y ) echo -e "Deleting current configuration\n"; rm -rf $EXKL_DIR;;
    n|N ) echo "Exiting."; exit 1;;
    * ) echo "Invalid choice. Exiting."; exit 1;;
  esac
fi

echo -e "Creating directory $EXKL_DIR\n"
mkdir $EXKL_DIR
cp -rf ./_build/prod/rel/exkl/* "$HOME/.config/exkl"

echo -e "\nCreating udev rule for HID device..."

if [ ! -f "$UDEV_RULE_FILE" ] || ! grep -q "$UDEV_RULE" "$UDEV_RULE_FILE"; then
  echo "$UDEV_RULE" | sudo tee "$UDEV_RULE_FILE" > /dev/null
  echo "Udev rule written to $UDEV_RULE_FILE"
else
  echo "Udev rule already exists in $UDEV_RULE_FILE"
fi

GROUP_NAME="plugdev"

# Check if group exists
if getent group "$GROUP_NAME" > /dev/null 2>&1; then
    echo "Group '$GROUP_NAME' already exists."
else
    echo "Group '$GROUP_NAME' does not exist. Creating it..."
    if sudo groupadd "$GROUP_NAME"; then
        echo "Group '$GROUP_NAME' created successfully."
    else
        echo "Failed to create group '$GROUP_NAME'."
        exit 1
    fi
fi

# === Add current user to plugdev group ===
if groups "$USER" | grep -qv '\bplugdev\b'; then
  echo "Adding user '$USER' to plugdev group..."
  sudo usermod -aG plugdev "$USER"
else
  echo "User '$USER' is already in plugdev group."
fi

# === Reload udev rules ===
echo "Reloading udev rules..."
sudo udevadm control --reload
sudo udevadm trigger

echo -e "\nUdev rule applied."

echo -e "Creating $SERVICE_NAME user systemd service...\n"

# Ensure service directory exists
mkdir -p "$SERVICE_DIR"

# Remove old service if exists
if [ -f "$SERVICE_DIR/$SERVICE_FILE" ]; then
  echo "Disabling and stopping old service..."
  systemctl --user disable "$SERVICE_NAME"
  systemctl --user stop "$SERVICE_NAME"
  echo "Deleting previous service file..."
  rm "$SERVICE_DIR/$SERVICE_FILE"
  echo "Old service file deleted."
fi

# Create new service file
cat <<EOF > "$SERVICE_DIR/$SERVICE_FILE"
[Unit]
Description=EXKL Application (User Service)
After=graphical-session.target
Requires=graphical-session.target

[Service]
Type=simple
ExecStartPre=/bin/sh -c 'while [ -z "$DISPLAY" ]; do echo "Waiting for DISPLAY..."; sleep 1; DISPLAY=$(printenv DISPLAY); done'
ExecStart=$EXEC_PATH start
ExecStop=$EXEC_PATH stop
Restart=on-failure
RestartSec=5s
Environment=PHX_SERVER=true
Environment=SECRET_KEY_BASE=$(echo "$SECRET_KEY_BASE")
Environment=DISPLAY=$DISPLAY

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# Reload user systemd and enable service
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME"

echo -e "\n$SERVICE_NAME user service has been installed and started.\n"

echo -e "Please log out and log back in for group changes to take effect."
