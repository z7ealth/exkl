#!/usr/bin/env bash
set -euo pipefail

APP_NAME="exkl"
ENV="prod"

NIFS_DIR="priv/nifs"
EXKL_DIR="$HOME/.config/exkl"

SERVICE_NAME="exkl"
SERVICE_FILE="$SERVICE_NAME.service"
SERVICE_DIR="$HOME/.config/systemd/user"
EXEC_PATH="$EXKL_DIR/bin/exkl"

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/exkl.desktop"

UDEV_GROUP="exkl"
UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl-hid.rules"
UDEV_RULE='SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", ATTRS{idProduct}=="0003", MODE="0660", GROUP="exkl", TAG+="uaccess"'

NEED_RELOGIN=false

log() {
  echo "[+] $1"
}

die() {
  echo "Error: $1" >&2
  exit 1
}

command -v mix >/dev/null 2>&1 || die "mix not found. Install Elixir/Erlang."
command -v gcc >/dev/null 2>&1 || die "gcc not found."
command -v sudo >/dev/null 2>&1 || die "sudo not found."
command -v systemctl >/dev/null 2>&1 || die "systemctl not found."

install -d "$NIFS_DIR"

log "Compiling NIFs..."

gcc -fPIC -shared \
  -I/usr/lib/erlang/usr/include \
  c_src/sensors_nif.c \
  -o "$NIFS_DIR/sensors_nif.so" \
  -lsensors

gcc -fPIC -shared \
  -I/usr/lib/erlang/usr/include \
  -I/usr/include/hidapi \
  c_src/hid_api_nif.c \
  -o "$NIFS_DIR/hid_api_nif.so" \
  -lhidapi-hidraw

log "Fetching dependencies..."
mix deps.get

if [[ -z "${SECRET_KEY_BASE:-}" ]]; then
  log "Generating SECRET_KEY_BASE..."
  SECRET_KEY_BASE="$(mix phx.gen.secret)"
fi

log "Using SECRET_KEY_BASE=${SECRET_KEY_BASE:0:8}...(hidden)"

log "Fetching production dependencies..."
MIX_ENV="$ENV" mix deps.get --only prod

log "Compiling project..."
MIX_ENV="$ENV" mix compile

log "Deploying assets..."
MIX_ENV="$ENV" mix assets.deploy

log "Building release..."
MIX_ENV="$ENV" mix release --overwrite

if [ -d "$EXKL_DIR" ]; then
  echo
  echo "The directory $EXKL_DIR already exists."
  read -r -p "Replace existing installation? (y/n): " choice

  case "$choice" in
    y|Y)
      log "Stopping existing service..."
      systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
      systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
      rm -rf "$EXKL_DIR"
      ;;
    n|N)
      echo "Exiting."
      exit 0
      ;;
    *)
      die "Invalid choice."
      ;;
  esac
fi

log "Installing release to $EXKL_DIR..."
install -d "$EXKL_DIR"
cp -a "_build/$ENV/rel/$APP_NAME/." "$EXKL_DIR/"

log "Creating HID udev rule..."

if ! getent group "$UDEV_GROUP" >/dev/null 2>&1; then
  sudo groupadd "$UDEV_GROUP"
fi

if ! groups "$USER" | grep -qw "$UDEV_GROUP"; then
  sudo usermod -aG "$UDEV_GROUP" "$USER"
  NEED_RELOGIN=true
fi

echo "$UDEV_RULE" | sudo tee "$UDEV_RULE_FILE" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger

log "Udev rule installed at $UDEV_RULE_FILE"

log "Creating user systemd service..."

install -d "$SERVICE_DIR"

if [ -f "$SERVICE_DIR/$SERVICE_FILE" ]; then
  systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
  rm -f "$SERVICE_DIR/$SERVICE_FILE"
fi

cat > "$SERVICE_DIR/$SERVICE_FILE" <<EOF
[Unit]
Description=EXKL Application
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
WorkingDirectory=$EXKL_DIR
ExecStart=$EXEC_PATH start
ExecStop=$EXEC_PATH stop
Restart=on-failure
RestartSec=5s

Environment=PHX_SERVER=true
Environment=SECRET_KEY_BASE=$SECRET_KEY_BASE
Environment=GTK_USE_PORTAL=1

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

log "Importing current graphical session environment..."

systemctl --user import-environment \
  DISPLAY \
  WAYLAND_DISPLAY \
  XDG_RUNTIME_DIR \
  DBUS_SESSION_BUS_ADDRESS \
  XDG_CURRENT_DESKTOP \
  2>/dev/null || true

log "Reloading user systemd..."
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"

if [ "$NEED_RELOGIN" = true ]; then
  echo
  echo "You were added to the '$UDEV_GROUP' group."
  echo "EXKL may not access the HID device until you log out and back in."
  echo "The service was installed but not started yet."
else
  systemctl --user restart "$SERVICE_NAME"
fi

log "Installing XDG autostart fallback..."

install -d "$AUTOSTART_DIR"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=EXKL
Comment=EXKL Application
Exec=/bin/sh -lc 'systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP; systemctl --user restart exkl.service'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo
echo "EXKL installed."

if [ "$NEED_RELOGIN" = true ]; then
  echo
  echo "Please log out and back in, then start it with:"
  echo
  echo "systemctl --user start exkl.service"
fi

echo
echo "For Hyprland, add this to ~/.config/hypr/hyprland.conf:"
echo
echo "exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP"
echo "exec-once = systemctl --user restart exkl.service"
