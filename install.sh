#!/usr/bin/env bash
set -euo pipefail

APP_NAME="exkl"
ENV="prod"

EXKL_DIR="$HOME/.config/exkl"

SERVICE_NAME="exkl"
SERVICE_FILE="$SERVICE_NAME.service"
SERVICE_DIR="$HOME/.config/systemd/user"
EXEC_PATH="$EXKL_DIR/bin/exkl"

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/exkl.desktop"

UDEV_GROUP="exkl"
UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl.rules"
UDEV_RULES=(
  'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", MODE="0660", GROUP="exkl", TAG+="uaccess"'
  'SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", ATTR{name}=="package-*", RUN+="/bin/chmod a+r %S%p/energy_uj"'
  'SUBSYSTEM=="powercap", KERNEL=="intel-rapl-mmio*", ATTR{name}=="package-*", RUN+="/bin/chmod a+r %S%p/energy_uj"'
)
LEGACY_UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl-hid.rules"

NEED_RELOGIN=false

log() {
  echo "[+] $1"
}

warn() {
  echo "[!] $1"
}

die() {
  echo "Error: $1" >&2
  exit 1
}

has_header() {
  local header="$1"
  [ -f "/usr/include/$header" ] || [ -f "/usr/local/include/$header" ]
}

check_dependencies() {
  log "Checking build tools..."

  command -v mix >/dev/null 2>&1 || die "mix not found. Install Elixir and Erlang/OTP."
  command -v erl >/dev/null 2>&1 || die "erl not found. Install Erlang/OTP."
  command -v gcc >/dev/null 2>&1 || die "gcc not found."
  command -v make >/dev/null 2>&1 || die "make not found."
  command -v sudo >/dev/null 2>&1 || die "sudo not found."
  command -v systemctl >/dev/null 2>&1 || die "systemctl not found."

  local missing=()

  if ! pkg-config --exists libsensors 2>/dev/null && ! has_header "sensors/sensors.h"; then
    missing+=("lm_sensors / libsensors development headers")
  fi

  if ! pkg-config --exists hidapi-hidraw 2>/dev/null \
    && ! has_header "hidapi/hidapi.h" \
    && ! has_header "hidapi.h"; then
    missing+=("hidapi development headers (hidapi-hidraw)")
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "Missing development libraries:"
    for dep in "${missing[@]}"; do
      echo "  - $dep"
    done
    echo
    echo "Install examples:"
    echo "  Arch / Manjaro:  sudo pacman -S erlang elixir gcc make lm_sensors hidapi wxwidgets-gtk3 webkit2gtk-4.1"
    echo "  Fedora:          sudo dnf install erlang elixir gcc make lm_sensors-devel hidapi-devel wxGTK3-devel webkit2gtk4.1-devel"
    echo "  Debian / Ubuntu: sudo apt install erlang elixir gcc make libsensors-dev libhidapi-dev libwxgtk3.2-dev libwebkit2gtk-4.1-dev"
    die "Install the packages above, then re-run ./install.sh"
  fi

  if ! ldconfig -p 2>/dev/null | grep -q 'libwx_.*gtk'; then
    warn "wxWidgets GTK libraries were not detected. The system tray / desktop window may fail to start."
    warn "On Arch / Manjaro install: wxwidgets-gtk3 webkit2gtk-4.1"
  fi

  if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    warn "No graphical session detected (DISPLAY / WAYLAND_DISPLAY unset)."
    warn "EXKL can still be installed, but the desktop UI starts with your graphical session."
  fi
}

check_dependencies

log "Checking native NIF build dependencies..."
make deps-check

log "Fetching dependencies..."
mix deps.get

if [[ -z "${SECRET_KEY_BASE:-}" ]]; then
  log "Generating SECRET_KEY_BASE..."
  SECRET_KEY_BASE="$(mix phx.gen.secret)"
fi

log "Using SECRET_KEY_BASE=${SECRET_KEY_BASE:0:8}...(hidden)"

log "Fetching production dependencies..."
MIX_ENV="$ENV" mix deps.get --only prod

log "Compiling project (including native NIFs)..."
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

log "Creating udev rules..."

if ! getent group "$UDEV_GROUP" >/dev/null 2>&1; then
  sudo groupadd "$UDEV_GROUP"
fi

if ! groups "$USER" | grep -qw "$UDEV_GROUP"; then
  sudo usermod -aG "$UDEV_GROUP" "$USER"
  NEED_RELOGIN=true
fi

if [ -f "$LEGACY_UDEV_RULE_FILE" ]; then
  sudo rm -f "$LEGACY_UDEV_RULE_FILE"
fi

{
  for rule in "${UDEV_RULES[@]}"; do
    echo "$rule"
  done
} | sudo tee "$UDEV_RULE_FILE" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=powercap --subsystem-match=hidraw

log "Udev rules installed at $UDEV_RULE_FILE"

log "Creating user systemd service..."

install -d "$SERVICE_DIR"

if [ -f "$SERVICE_DIR/$SERVICE_FILE" ]; then
  systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
  rm -f "$SERVICE_DIR/$SERVICE_FILE"
fi

cat > "$SERVICE_DIR/$SERVICE_FILE" <<EOF
[Unit]
Description=EXKL — DeepCool Digital for Linux
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
Environment=PORT=4500
Environment=GTK_USE_PORTAL=1
Environment=GDK_BACKEND=x11

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

log "Reloading user systemd..."
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"

if [ "$NEED_RELOGIN" = true ]; then
  echo
  echo "You were added to the '$UDEV_GROUP' group."
  echo "EXKL may not access DeepCool HID devices until you log out and back in."
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
Comment=DeepCool Digital display control for Linux
Exec=/bin/sh -lc 'systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP; systemctl --user restart exkl.service'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo
echo "EXKL installed."
echo
echo "UI:         Open 'Show window' from the system tray icon"
echo "Observer:   $EXKL_DIR/bin/exkl remote   # then :observer.start()"
echo "Wayland:    install.sh sets GDK_BACKEND=x11 in exkl.service (tray on GNOME Wayland)"
echo "Service:    systemctl --user status exkl.service"
echo "Logs:       journalctl --user -u exkl.service -f"
echo "Uninstall:  ./uninstall.sh"
echo

if [ "$NEED_RELOGIN" = true ]; then
  echo "Log out and back in, then start EXKL with:"
  echo "  systemctl --user start exkl.service"
  echo
fi
