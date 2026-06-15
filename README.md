# ![EXKL Logo](./priv/static/images/exkl_logo.png) EXKL

Unofficial Linux control software for **DeepCool Digital** CPU coolers and related HID displays. EXKL drives the cooler top screen over USB, exposes a local web dashboard, and runs from the system tray.

Successor to the original Rust tray app [AKL](https://github.com/z7ealth/akl).

<img src="./priv/static/images/ak_cooler.jpeg" alt="AK Cooler" style="width: 400px;" />

## Features

- Auto-discover connected DeepCool HID devices (vendor `3633`)
- Live metrics on the cooler display: CPU temperature (°C / °F) and CPU utilization
- Web dashboard with CPU/GPU temperature, load, frequency, and power
- System tray icon with window, About dialog, and Exit
- User systemd service + XDG autostart fallback
- udev rules for HID access and Intel RAPL CPU power readings

## Supported devices

USB vendor ID is always **3633** (`0x3633`). Supported product IDs:

| PID | Device | Protocol |
|-----|--------|----------|
| 1 | AK400 DIGITAL | AK series |
| 2 | AK620 DIGITAL (legacy) | AK series |
| 3 | AK500 DIGITAL | AK series |
| 4 | AK500S DIGITAL | AK series |
| 5 | CH560 DIGITAL | CH series |
| 7 | MORPHEUS | CH series |
| 21 | CH360 DIGITAL | CH series |
| 41 | AK620 G2 DIGITAL NYX | G2 series |
| 42 | AK700 DIGITAL NYX | G2 series |
| 43 | AK400 G2 DIGITAL NYX | G2 series |
| 44 | AK500 G2 DIGITAL NYX | G2 series |

Other DeepCool HID devices may appear in the dashboard as **Unsupported** until added to the catalog. See [deepcool-digital-linux device list](https://github.com/Nortank12/deepcool-digital-linux/blob/main/device-list/README.md) for reference PIDs.

## Dependencies

### Build & runtime (required)

| Component | Purpose |
|-----------|---------|
| Erlang/OTP | BEAM runtime |
| Elixir | Application build |
| GCC, make | Native NIFs (`sensors_nif`, `hid_api_nif`) |
| lm_sensors (`libsensors`) | CPU temperature via `sensors` |
| hidapi (hidraw) | USB HID communication with the cooler |

### Desktop UI (required for tray / About window)

| Component | Purpose |
|-----------|---------|
| wxWidgets (GTK3) | System tray and About dialog |
| WebKitGTK 4.1 | Embedded dashboard window |

### Optional

| Component | Purpose |
|-----------|---------|
| `rocm-smi` / AMDGPU sysfs | AMD GPU metrics |
| Intel RAPL (`/sys/class/powercap`) | CPU power (udev rule installed by `install.sh`) |
| NVIDIA driver sysfs | NVIDIA GPU metrics when present |

### Install packages by distro

**Arch / Manjaro**

```bash
sudo pacman -S erlang elixir gcc make lm_sensors hidapi wxwidgets-gtk3 webkit2gtk-4.1
```

**Fedora**

```bash
sudo dnf install erlang elixir gcc make lm_sensors-devel hidapi-devel wxGTK3-devel webkit2gtk4.1-devel
```

**Debian / Ubuntu**

```bash
sudo apt install erlang elixir gcc make libsensors-dev libhidapi-dev libwxgtk3.2-dev libwebkit2gtk-4.1-dev
```

Verify native build dependencies:

```bash
make deps-check
```

## Install

```bash
git clone https://github.com/z7ealth/exkl.git
cd exkl
./install.sh
```

The installer will:

1. Check dependencies and compile native NIFs
2. Build a production release
3. Install to `~/.config/exkl`
4. Create udev rules (`/etc/udev/rules.d/99-exkl.rules`) and add your user to the `exkl` group
5. Enable the user systemd service `exkl.service`

After install:

- **Dashboard:** http://localhost:4500
- **Logs:** `journalctl --user -u exkl.service -f`
- **Status:** `systemctl --user status exkl.service`

If you were added to the `exkl` group, **log out and back in** before the HID device is accessible.

## Uninstall

```bash
./uninstall.sh
```

Removes the user service, autostart entry, and `~/.config/exkl`. Optionally removes udev rules and the `exkl` group.

## Development

```bash
mix setup          # deps + assets
make all           # build NIFs only
mix phx.server     # dev server (http://localhost:4000)
```

Native NIFs are rebuilt automatically on `mix compile` via `elixir_make` and the project `Makefile`.

For the desktop tray locally:

```bash
GDK_BACKEND=x11 mix phx.server
```

## Adding a new device

1. **Find the USB IDs**  
   Run `lsusb` and look for `3633:xxxx`, or check the [deepcool-digital-linux device list](https://github.com/Nortank12/deepcool-digital-linux/blob/main/device-list/README.md).

2. **Pick an encoder family** in `lib/exkl/hid_device/catalog.ex`:
   - `:ak_series` — AK400/500/620 legacy air coolers (`lib/exkl/hid_devices/ak_series.ex`)
   - `:ch_series` — dual CPU/GPU case displays (`lib/exkl/hid_devices/ch_series.ex`)
   - `:g2_series` — G2/NYX binary packet format (`lib/exkl/hid_devices/g2_series.ex`)

3. **Add a device struct** under `lib/exkl/hid_devices/` implementing `Exkl.HidDevice.Behaviour`, then delegate to `Exkl.HidDevice.Impl` (see `ak500.ex` or `ak620.ex`).

4. **Register the PID** in `lib/exkl/hid_device/catalog.ex`:

   ```elixir
   99 => {Exkl.HidDevices.MyDevice, :ak_series, "MY DEVICE LABEL"},
   ```

5. **Test** with the device plugged in:

   ```bash
   mix phx.server
   ```

   The dashboard **DeepCool devices** panel should list it as Connected. Check logs for HID write errors.

6. **Protocol tweaks** — if the family encoder is wrong, inspect packets in the matching `*_series.ex` module against [deepcool-digital-linux mapping tables](https://github.com/Nortank12/deepcool-digital-linux/tree/main/device-list/tables).

No changes to `Exkl.Display` are needed; discovery and workers are automatic once the catalog entry exists.

## Acknowledgements

- [Nortank12/deepcool-digital-linux](https://github.com/Nortank12/deepcool-digital-linux) — HID protocol reverse engineering and device PID tables
- [raghulkrishna/deepcool-ak620-digital-linux](https://github.com/raghulkrishna/deepcool-ak620-digital-linux) — early AK620 Linux driver that inspired the original work
- [Algorithm0/deepcool-digital-info](https://github.com/Algorithm0/deepcool-digital-info) — community packet format notes

## License

MIT — see [LICENSE](./LICENSE).
