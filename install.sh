#!/usr/bin/env bash
set -euo pipefail

APP_NAME="exkl"
ENV="prod"

EXKL_DIR="$HOME/.config/exkl"

SERVICE_NAME="exkl"
SERVICE_FILE="$SERVICE_NAME.service"
SERVICE_DIR="$HOME/.config/systemd/user"
EXEC_PATH="$EXKL_DIR/bin/exkl"
LAUNCH_PATH="$EXKL_DIR/bin/launch"

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/exkl.desktop"

DESKTOP_APP_DIR="$HOME/.local/share/applications"
DESKTOP_APP_FILE="$DESKTOP_APP_DIR/exkl.desktop"
ICON_PATH="$EXKL_DIR/share/exkl.png"

UDEV_GROUP="exkl"
UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl.rules"
UDEV_RULES=(
  'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", MODE="0660", GROUP="exkl", TAG+="uaccess"'
  'SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", ATTR{name}=="package-*", RUN+="/bin/chmod a+r %S%p/energy_uj"'
  'SUBSYSTEM=="powercap", KERNEL=="intel-rapl-mmio*", ATTR{name}=="package-*", RUN+="/bin/chmod a+r %S%p/energy_uj"'
)
LEGACY_UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl-hid.rules"

NEED_REBOOT=false

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

MIN_OTP=28
MIN_ELIXIR_VERSION=1.19.0

check_runtime_versions() {
  local otp elixir_version

  otp=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' 2>/dev/null || echo "0")

  if ! [[ "$otp" =~ ^[0-9]+$ ]] || [ "$otp" -lt "$MIN_OTP" ]; then
    die "Erlang/OTP ${MIN_OTP}+ required (found OTP ${otp}). On Fedora, dnf often ships an older erlang — install OTP ${MIN_OTP}+ via asdf-erlang or kerl."
  fi

  if ! elixir -e 'min = Version.parse!("'"$MIN_ELIXIR_VERSION"'"); cur = Version.parse!(System.version()); System.halt(if Version.compare(cur, min) == :lt, do: 1, else: 0)' >/dev/null 2>&1; then
    elixir_version=$(elixir --short-version 2>/dev/null || echo "unknown")
    die "Elixir ${MIN_ELIXIR_VERSION}+ required (found ${elixir_version}). On Fedora, dnf often ships an older elixir — install ${MIN_ELIXIR_VERSION}+ via asdf-elixir."
  fi

  log "Toolchain OK (OTP ${otp}, Elixir $(elixir --short-version))"
}

check_dependencies() {
  log "Checking build tools..."

  command -v mix >/dev/null 2>&1 || die "mix not found. Install Elixir ${MIN_ELIXIR_VERSION}+ and Erlang/OTP ${MIN_OTP}+."
  command -v erl >/dev/null 2>&1 || die "erl not found. Install Erlang/OTP ${MIN_OTP}+."
  check_runtime_versions
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

install -d "$(dirname "$ICON_PATH")"
cp "priv/static/images/icon/icon-light.png" "$ICON_PATH"
chmod +x "$LAUNCH_PATH"

log "Generating SECRET_KEY_BASE..."
SECRET_KEY_BASE="$(mix phx.gen.secret | tr -d '[:space:]')"

log "Writing runtime environment to $EXKL_DIR/env..."
umask 077
cat > "$EXKL_DIR/env" <<EOF
PHX_SERVER=true
SECRET_KEY_BASE=$SECRET_KEY_BASE
PORT=4500
GTK_USE_PORTAL=1
GDK_BACKEND=x11
EOF
chmod 600 "$EXKL_DIR/env"
umask 022

log "Using SECRET_KEY_BASE=${SECRET_KEY_BASE:0:8}...(hidden, stored in $EXKL_DIR/env)"

log "Creating udev rules..."

if ! getent group "$UDEV_GROUP" >/dev/null 2>&1; then
  sudo groupadd "$UDEV_GROUP"
fi

if ! groups "$USER" | grep -qw "$UDEV_GROUP"; then
  sudo usermod -aG "$UDEV_GROUP" "$USER"
  NEED_REBOOT=true
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

EnvironmentFile=$EXKL_DIR/env

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

log "Reloading user systemd..."
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME"

log "Installing XDG autostart fallback..."

install -d "$AUTOSTART_DIR"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=EXKL
Comment=DeepCool Digital display control for Linux
Icon=$ICON_PATH
StartupWMClass=Erlang
Exec=/bin/sh -lc 'systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP; systemctl --user restart exkl.service'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

log "Installing desktop entry for GNOME dock name and icon..."

install -d "$DESKTOP_APP_DIR"

cat > "$DESKTOP_APP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=EXKL
Comment=DeepCool Digital display control for Linux
Icon=$ICON_PATH
StartupWMClass=Erlang
Exec=$LAUNCH_PATH
Terminal=false
Categories=Utility;
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_APP_DIR" 2>/dev/null || true
fi

echo
echo "EXKL installed."
echo
echo "UI:         Open 'Show window' from the system tray icon"
echo "Launcher:   EXKL in the app menu (or: $LAUNCH_PATH)"
echo "Observer:   $EXKL_DIR/bin/exkl remote   # then :observer.start()"
echo "Wayland:    install.sh sets GDK_BACKEND=x11 in exkl.service (tray on GNOME Wayland)"
echo "Service:    systemctl --user status exkl.service"
echo "Logs:       journalctl --user -u exkl.service -f"
echo "Uninstall:  ./uninstall.sh"
echo

if [ "$NEED_REBOOT" = true ]; then
  echo "Reboot:     you were added to the '$UDEV_GROUP' group — reboot before HID devices are accessible"
  echo
fi
