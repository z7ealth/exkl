defmodule Exkl.AK do
  @type modes() :: :start | :cpu_temp_c | :cpu_temp_f | :cpu_util | :auto

  @type t() :: %__MODULE__{
          metrics_value: float(),
          mode: modes(),
          gpu_temp_c: float() | nil,
          gpu_util: float() | nil,
          cpu_freq_mhz: float() | nil,
          gpu_freq_mhz: float() | nil,
          cpu_power_w: float() | nil,
          gpu_power_w: float() | nil
        }
  defstruct [
    metrics_value: 0.0,
    mode: :cpu_temp_c,
    gpu_temp_c: nil,
    gpu_util: nil,
    cpu_freq_mhz: nil,
    gpu_freq_mhz: nil,
    cpu_power_w: nil,
    gpu_power_w: nil
  ]
end
