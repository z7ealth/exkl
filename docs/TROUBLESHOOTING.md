# Troubleshooting

## Quick fixes

| Problem | Fix |
|---------|-----|
| **Blank tray window** | Open http://localhost:4500 in a browser. Install `wxwidgets-gtk3` and `webkit2gtk-4.1`. |
| **No tray icon (GNOME Wayland)** | `GDK_BACKEND=x11` in `~/.config/exkl/env`, then `systemctl --user restart exkl.service`. |
| **Blank window on NVIDIA** | `WEBKIT_DISABLE_COMPOSITING_MODE=1` in `~/.config/exkl/env`, restart service. |
| **Build fails on Fedora** | Use OTP 28+ and Elixir 1.19+ ([asdf](https://asdf-vm.com/) or [kerl](https://github.com/kerl/kerl)). Run `make deps-check`. |
| **Device not updating** | Reboot after install (udev group). Check `journalctl --user -u exkl.service -f`. |
| **Old tray/window icon after upgrade** | `MIX_ENV=prod mix release`, `./install.sh`, restart service. Icons load from the release `priv/` at runtime — a service restart alone is not enough if the release was not rebuilt. |
| **Wrong launcher icon in GNOME** | Re-run `./install.sh`, or copy `~/.config/exkl/share/exkl.png` from a fresh build, then `update-desktop-database ~/.local/share/applications`. |
| **Tray gone after Exit** | Expected — Exit closes the GUI only. `systemctl --user restart exkl.service` to restore the tray. Core, HID, and http://localhost:4500 keep running until the service stops. |

Env changes apply at **service start** only — always run `systemctl --user restart exkl.service` after editing `~/.config/exkl/env`.

## Blank embedded dashboard

**1. Confirm the server is running**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4500/
```

`200` means EXKL is fine; the issue is the WebView.

**2. Browser workaround**

Open http://localhost:4500 in Firefox or Chromium. Tray and HID control keep working.

**3. Missing libraries**

```bash
ldd /usr/lib/erlang/lib/wx-*/priv/wxe_driver.so | grep -E 'not found|webkit|webview'
```

No `not found` lines — install `wxwidgets-gtk3` and `webkit2gtk-4.1` if needed.

## NVIDIA GPUs

WebKitGTK + proprietary NVIDIA drivers often produce a blank embedded window ([WebKit #180739](https://bugs.webkit.org/show_bug.cgi?id=180739)).

Add to `~/.config/exkl/env`:

```bash
WEBKIT_DISABLE_COMPOSITING_MODE=1
```

Restart the service. Lighter alternatives to try first:

```bash
WEBKIT_DISABLE_DMABUF_RENDERER=1
__NV_DISABLE_EXPLICIT_SYNC=1   # Wayland + NVIDIA
```

**Example env (NVIDIA + GNOME Wayland):**

```bash
PHX_SERVER=true
SECRET_KEY_BASE=...
PORT=4500
GTK_USE_PORTAL=1
GDK_BACKEND=x11
WEBKIT_DISABLE_COMPOSITING_MODE=1
```

**NVIDIA GPU metrics** need the proprietary driver and a working `nvidia-smi` — nouveau is not supported.

```bash
nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits
```

## GNOME Wayland

`install.sh` sets `GDK_BACKEND=x11` in `~/.config/exkl/env`. For local dev:

```bash
GDK_BACKEND=x11 mix phx.server
```

## Logs

```bash
journalctl --user -u exkl.service -f
systemctl --user status exkl.service
```
