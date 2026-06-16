# Architecture

EXKL is an OTP application. The root supervisor starts Phoenix, metrics collection, HID device workers, and the desktop tray UI.

## Supervisor tree

```mermaid
graph TD
  Root["Exkl.Supervisor<br/><i>one_for_one</i>"]

  Root --> Telemetry["ExklWeb.Telemetry"]
  Root --> DNS["DNSCluster"]
  Root --> PubSub["Phoenix.PubSub"]
  Root --> Endpoint["ExklWeb.Endpoint"]
  Root --> Core["Exkl.Core"]
  Root --> Display["Exkl.Display"]
  Root --> GUI["Exkl.GUI"]

  Display --> Worker1["Display.Worker"]
  Display --> WorkerN["Display.Worker …<br/><i>one per device</i>"]

  GUI --> Desktop["Exkl.Desktop"]
  Desktop --> Tray["wxTaskBarIcon"]
  Desktop --> Window["wxFrame + WebView"]
```

`Exkl.Display` discovers DeepCool HID devices (vendor `3633`) at startup and starts one `Exkl.Display.Worker` per opened device. `Exkl.GUI` starts `Exkl.Desktop` (system tray + embedded dashboard).

## Data flow

```mermaid
flowchart LR
  subgraph sources["Metrics"]
    NIF["Sensors / HID NIFs"]
    Sysfs["sysfs / RAPL / lm_sensors"]
  end

  Core["Exkl.Core"]
  PubSub["PubSub cpu_metrics"]
  Workers["Display.Worker"]
  HID["USB HID display"]
  Endpoint["ExklWeb.Endpoint"]
  LV["DashboardLive"]
  WebView["Desktop WebView"]

  Sysfs --> Core
  NIF --> Core
  Core -->|"every 1s"| PubSub
  PubSub --> Workers
  PubSub --> LV
  Workers -->|"encode + write"| HID
  Endpoint --> LV
  WebView --> Endpoint
```

`Exkl.Core` polls CPU/GPU sensors and publishes `{:cpu_metrics, %Exkl.AK{}}` on PubSub. HID workers push encoded packets to the cooler display; the dashboard subscribes via the WebView (or browser at `:4500`).

## Key modules

| Module | Role |
|--------|------|
| `Exkl.Core` | Sensor polling, mode switching, PubSub broadcast |
| `Exkl.Display` | HID discovery and worker supervision |
| `Exkl.Display.Worker` | Per-device encode + USB write |
| `Exkl.HidDevice.Catalog` | USB PID → encoder family mapping |
| `Exkl.Desktop` | wx tray icon and WebView window |
| `ExklWeb.Endpoint` | Phoenix HTTP server (port 4500) |

Encoder families: `ak_series`, `ch_series` (dual CPU/GPU), `g2_series` — see `lib/exkl/hid_devices/`.
