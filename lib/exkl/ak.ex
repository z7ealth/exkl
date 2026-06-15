defmodule Exkl.AK do
  @type modes() :: :start | :cpu_temp_c | :cpu_temp_f | :cpu_util | :auto

  @type t() :: %__MODULE__{
          metrics_value: float(),
          mode: modes(),
          gpu_temp_c: float() | nil,
          gpu_util: float() | nil
        }
  defstruct [metrics_value: 0.0, mode: :cpu_temp_c, gpu_temp_c: nil, gpu_util: nil]
end
