# Development

Requires **OTP 28+** and **Elixir 1.19+**.

## Local setup

```bash
mix setup
GDK_BACKEND=x11 mix phx.server   # GNOME Wayland
```

Open **Show window** from the system tray, or http://localhost:4500 in a browser. NIFs rebuild on `mix compile`.

```bash
make deps-check
make all
mix assets.build    # after CSS/JS changes
```

## Production-like install

```bash
MIX_ENV=prod mix release
./install.sh
systemctl --user restart exkl.service
```

Re-run `./install.sh` after release or icon changes so `~/.config/exkl/` picks up the new `priv/` tree and launcher icon.

## Observer

```bash
~/.config/exkl/bin/exkl remote
```

```elixir
:observer.start()
```

## UI and assets

- Dashboard: `lib/exkl_web/live/dashboard_live/index.ex`
- Live droplet icon: `lib/exkl_web/components/icon.ex` (`<.exkl_icon temp={…} unit={…} />`)
- Styles: `assets/css/app.css` (Tailwind v4 + daisyUI themes)
- App icons: `priv/static/images/icon/` — PNGs can be regenerated from the icon pack’s `render.py`

Tray **Exit** during dev closes the wx UI only; restart the app or run `systemctl --user restart exkl.service` to get the tray back.

## Adding a new device

1. USB IDs: `lsusb` → vendor `3633`, or [device list](https://github.com/Nortank12/deepcool-digital-linux/blob/main/device-list/README.md).
2. Encoder in `lib/exkl/hid_device/catalog.ex`: `:ak_series`, `:ch_series`, or `:g2_series`.
3. Struct under `lib/exkl/hid_devices/` (see `ak500.ex`, `ak620.ex`).
4. Register PID in `catalog.ex`.
5. Test plugged in; check logs and the **DeepCool devices** panel.

Protocol: [mapping tables](https://github.com/Nortank12/deepcool-digital-linux/tree/main/device-list/tables).

## See also

- [Architecture](./ARCHITECTURE.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
