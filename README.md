# ![EXKL Logo](./priv/static/images/exkl_logo.png) EXKL

Unofficial Linux app for **DeepCool Digital** coolers and case displays (USB vendor `3633`). Drives the HID screen, shows CPU/GPU metrics in the system tray, and runs as a user service.

<img src="./priv/static/images/ak_cooler.jpeg" alt="AK Cooler" style="width: 400px;" />

## Quick start

**1. Install dependencies** (pick your distro):

| Distro | Command |
|--------|---------|
| Arch / Manjaro | `sudo pacman -S erlang elixir gcc make lm_sensors hidapi wxwidgets-gtk3 webkit2gtk-4.1` |
| Fedora | `sudo dnf install @development-tools erlang elixir gcc make lm_sensors-devel hidapi-devel wxGTK-devel webkit2gtk4.1-devel` |
| Debian / Ubuntu | `sudo apt install erlang elixir gcc make libsensors-dev libhidapi-dev libwxgtk3.2-dev libwebkit2gtk-4.1-dev` |

**2. Install EXKL:**

```bash
git clone https://github.com/z7ealth/exkl.git
cd exkl
./install.sh
```

**3. Reboot** if the installer added you to the `exkl` group (needed for USB access).

**4. Open the UI** from the system tray → **Show window**, or open `http://localhost:4500` in a browser.

## Requirements

- **Erlang/OTP 28+** and **Elixir 1.19+** (check with `elixir --version`)
- **Fedora:** `dnf` often ships older Erlang/Elixir — use [asdf](https://asdf-vm.com/) or [kerl](https://github.com/kerl/kerl) before running `./install.sh`
- **NVIDIA GPU metrics:** proprietary driver + `nvidia-smi` (nouveau is not supported)

## After install

| Action | Command / location |
|--------|-------------------|
| Dashboard (browser) | http://localhost:4500 |
| Tray window | System tray → **Show window** |
| App launcher | **EXKL** in the application menu |
| Logs | `journalctl --user -u exkl.service -f` |
| Status | `systemctl --user status exkl.service` |
| Config / secrets | `~/.config/exkl/env` |

Issues? See [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md).

## Supported devices

USB vendor ID **3633**. Full PID list: [deepcool-digital-linux device list](https://github.com/Nortank12/deepcool-digital-linux/blob/main/device-list/README.md).

| USB ID | Device |
|--------|--------|
| `3633:0001`–`0004` | AK400 / AK620 / AK500 / AK500S |
| `3633:0005` | CH560 DIGITAL |
| `3633:0007` | MORPHEUS |
| `3633:0015` | CH360 DIGITAL |
| `3633:0029`–`002c` | AK620 G2 / AK700 / AK400 G2 / AK500 G2 NYX |

Other `3633` devices may show as **Detected** or **Unsupported** until added to the catalog.

## Uninstall

```bash
./uninstall.sh
```

## Docs

| Doc | Contents |
|-----|----------|
| [Troubleshooting](./docs/TROUBLESHOOTING.md) | Blank WebView, NVIDIA, Wayland, logs |
| [Architecture](./docs/ARCHITECTURE.md) | Supervisor tree, data flow, modules |
| [Development](./docs/DEVELOPMENT.md) | Local setup, adding devices |

## License

MIT — see [LICENSE](./LICENSE).

## Acknowledgements

[Nortank12/deepcool-digital-linux](https://github.com/Nortank12/deepcool-digital-linux) · [raghulkrishna/deepcool-ak620-digital-linux](https://github.com/raghulkrishna/deepcool-ak620-digital-linux) · [Algorithm0/deepcool-digital-info](https://github.com/Algorithm0/deepcool-digital-info)
