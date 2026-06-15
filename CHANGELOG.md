# Changelog

All notable changes to EXKL are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-06-15

Compared to [0.1.0](https://github.com/z7ealth/exkl/commit/aa31fe96ce2569ccdfe14e034c68818767cdf431).

### Added

- **Multi-device HID support** — auto-discovery of DeepCool USB HID devices (vendor `3633`) with one worker per connected display.
- **Protocol families** — modular encoders for AK series, CH series (CPU + GPU case displays), and G2/NYX series.
- **Device catalog** — AK400/620/500/500S, MORPHEUS, CH360/CH560, and AK400/500/620/700 G2 NYX variants.
- **GPU metrics** — temperature, utilization, frequency, and power on the dashboard.
- **CPU power** — Intel RAPL readings via `intel-rapl` and `intel-rapl-mmio` sysfs (udev rules installed by `install.sh`).
- **Dashboard UI** — redesigned layout with metric cards, separate CPU/GPU rows, and a live **DeepCool devices** panel.
- **Tray About dialog** — app name, version, description, copyright, and license link.
- **`Exkl.Bar`** — shared segment logic for the HID utilization bar (displayed value ÷ 10, 0–10 segments).
- **Native build tooling** — `Makefile` with `deps-check` and `elixir_make` integration.
- **Documentation** — architecture diagrams (supervisor tree + data flow), dependency tables per distro, device-add guide, Wayland tray notes, and Observer instructions (`bin/exkl remote` → `:observer.start()`).
- **Distributed release node** — release runs as `exkl@127.0.0.1` so `bin/exkl remote` can attach to a running instance.

### Changed

- **Scope** — from AK500-focused cooler app to general DeepCool Digital control (coolers, AIOs, and case displays).
- **`Exkl.Display`** — refactored from a single GenServer into a supervisor with `Exkl.Display.Worker` children.
- **udev rules** — all DeepCool HID devices (`3633`) plus RAPL `energy_uj` permissions (replaces AK500-only rule).
- **`install.sh` / `uninstall.sh`** — dependency checks, production release build, improved service setup, and clearer post-install messages.
- **Logo and branding** — updated EXKL logo asset.
- **Dependencies** — Phoenix, LiveView, and related packages updated.

### Fixed

- **HID utilization bar** — segments now follow the displayed metric (not always raw CPU util); values clamped correctly at 0% and above 100%.
- **AK620 G2 NYX** — G2-series packet encoding and device support.
- **systemd user service** — removed `AmbientCapabilities` / `CapabilityBoundingSet` (not permitted in user units; caused exit status 218).
- **Wayland tray** — documented `GDK_BACKEND=x11` for GNOME Wayland; install sets it in `exkl.service`.

### Removed

- **zenpower dependency** — CPU temperature and power are read via lm_sensors, hwmon, and RAPL instead.
- **Hard-coded AK500-only HID open** — replaced by catalog-based discovery and per-device workers.

---

## [0.1.0] - 2026-06-12

Initial public release ([aa31fe9](https://github.com/z7ealth/exkl/commit/aa31fe96ce2569ccdfe14e034c68818767cdf431)).

- AK500 DIGITAL HID control (temperature °C/°F and CPU utilization on the cooler screen).
- Embedded dashboard with CPU metrics.
- wxWidgets system tray, embedded WebView window, and basic tray menu.
- User systemd service, XDG autostart fallback, and udev rule for AK500 HID access.
- Native NIFs for lm_sensors and hidapi.
