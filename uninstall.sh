#!/usr/bin/env bash
set -euo pipefail

EXKL_DIR="$HOME/.config/exkl"

SERVICE_NAME="exkl"
SERVICE_FILE="$SERVICE_NAME.service"
SERVICE_DIR="$HOME/.config/systemd/user"

AUTOSTART_FILE="$HOME/.config/autostart/exkl.desktop"

DESKTOP_APP_FILE="$HOME/.local/share/applications/exkl.desktop"

UDEV_GROUP="exkl"
UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl.rules"
LEGACY_UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl-hid.rules"

log() {
  echo "[+] $1"
}

warn() {
  echo "[!] $1"
}

echo "This will uninstall EXKL for user: $USER"
echo "  - systemd user service"
echo "  - XDG autostart entry"
echo "  - desktop launcher entry"
echo "  - release files in $EXKL_DIR"
echo
read -r -p "Do you want to proceed? [y/N]: " choice
choice=${choice:-N}

case "$choice" in
  y|Y) ;;
  n|N|*)
    echo "Exiting."
    exit 0
    ;;
esac

log "Stopping user service..."

systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true

log "Killing leftover EXKL processes..."

pkill -f "$EXKL_DIR/bin/exkl" 2>/dev/null || true
pkill -f "beam.smp.*exkl" 2>/dev/null || true

log "Removing user systemd service..."

if [ -f "$SERVICE_DIR/$SERVICE_FILE" ]; then
  rm -f "$SERVICE_DIR/$SERVICE_FILE"
fi

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user reset-failed "$SERVICE_NAME" 2>/dev/null || true

log "Removing autostart entry..."

if [ -f "$AUTOSTART_FILE" ]; then
  rm -f "$AUTOSTART_FILE"
fi

log "Removing desktop entry..."

if [ -f "$DESKTOP_APP_FILE" ]; then
  rm -f "$DESKTOP_APP_FILE"
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

log "Removing application files..."

if [ -d "$EXKL_DIR" ]; then
  rm -rf "$EXKL_DIR"
fi

echo
read -r -p "Remove EXKL udev rules? [y/N]: " remove_udev
remove_udev=${remove_udev:-N}

case "$remove_udev" in
  y|Y)
    if [ -f "$UDEV_RULE_FILE" ]; then
      log "Removing udev rules..."
      sudo rm -f "$UDEV_RULE_FILE"
      sudo udevadm control --reload-rules
      sudo udevadm trigger --subsystem-match=powercap --subsystem-match=hidraw
    else
      warn "Udev rules not found at $UDEV_RULE_FILE"
    fi

    if [ -f "$LEGACY_UDEV_RULE_FILE" ]; then
      sudo rm -f "$LEGACY_UDEV_RULE_FILE"
      sudo udevadm control --reload-rules
      sudo udevadm trigger --subsystem-match=powercap --subsystem-match=hidraw
    fi
    ;;
  n|N|*)
    warn "Keeping udev rules at $UDEV_RULE_FILE"
    ;;
esac

echo
read -r -p "Remove '$UDEV_GROUP' group? [y/N]: " remove_group
remove_group=${remove_group:-N}

case "$remove_group" in
  y|Y)
    if getent group "$UDEV_GROUP" >/dev/null 2>&1; then
      log "Removing group '$UDEV_GROUP'..."
      sudo groupdel "$UDEV_GROUP" || warn "Could not remove group '$UDEV_GROUP'. It may still be in use."
    else
      warn "Group '$UDEV_GROUP' does not exist."
    fi
    ;;
  n|N|*)
    warn "Keeping group '$UDEV_GROUP'."
    ;;
esac

echo
echo "EXKL has been uninstalled."
echo
echo "Verify with:"
echo "  systemctl --user status exkl.service"
echo "  ps aux | grep '[e]xkl'"
