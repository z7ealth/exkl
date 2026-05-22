#!/usr/bin/env bash
set -euo pipefail

APP_NAME="exkl"

EXKL_DIR="$HOME/.config/exkl"

SERVICE_NAME="exkl"
SERVICE_FILE="$SERVICE_NAME.service"
SERVICE_DIR="$HOME/.config/systemd/user"

AUTOSTART_FILE="$HOME/.config/autostart/exkl.desktop"

UDEV_GROUP="exkl"
UDEV_RULE_FILE="/etc/udev/rules.d/99-exkl-hid.rules"

log() {
  echo "[+] $1"
}

warn() {
  echo "[!] $1"
}

echo "This will uninstall EXKL from this user."
echo
read -r -p "Do you want to proceed? (y/n): " choice

case "$choice" in
  y|Y) ;;
  n|N)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac

log "Stopping user service..."

systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true

log "Killing leftover EXKL processes..."

pkill -f "$EXKL_DIR/bin/exkl" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true

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

log "Removing application files..."

if [ -d "$EXKL_DIR" ]; then
  rm -rf "$EXKL_DIR"
fi

echo
read -r -p "Remove EXKL HID udev rule? (y/n): " remove_udev

case "$remove_udev" in
  y|Y)
    if [ -f "$UDEV_RULE_FILE" ]; then
      log "Removing udev rule..."
      sudo rm -f "$UDEV_RULE_FILE"
      sudo udevadm control --reload-rules
      sudo udevadm trigger
    else
      warn "Udev rule not found."
    fi
    ;;
  n|N)
    warn "Keeping udev rule at $UDEV_RULE_FILE"
    ;;
  *)
    warn "Invalid choice. Keeping udev rule."
    ;;
esac

echo
read -r -p "Remove '$UDEV_GROUP' group? (y/n): " remove_group

case "$remove_group" in
  y|Y)
    if getent group "$UDEV_GROUP" >/dev/null 2>&1; then
      log "Removing group '$UDEV_GROUP'..."
      sudo groupdel "$UDEV_GROUP" || warn "Could not remove group '$UDEV_GROUP'. It may still be in use."
    else
      warn "Group '$UDEV_GROUP' does not exist."
    fi
    ;;
  n|N)
    warn "Keeping group '$UDEV_GROUP'."
    ;;
  *)
    warn "Invalid choice. Keeping group '$UDEV_GROUP'."
    ;;
esac

echo
echo "EXKL has been uninstalled."
echo
echo "Verify with:"
echo "  systemctl --user status exkl.service"
echo "  ps aux | grep '[e]xkl'"
