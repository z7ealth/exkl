# Development

Requires **OTP 28+** and **Elixir 1.19+**.

## Local setup

```bash
mix setup
GDK_BACKEND=x11 mix phx.server   # GNOME Wayland
```

Open **Show window** from the system tray. NIFs rebuild on `mix compile`.

```bash
make deps-check
make all
```

## Observer

```bash
~/.config/exkl/bin/exkl remote
```

```elixir
:observer.start()
```

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
