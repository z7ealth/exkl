defmodule Exkl.AK do
  @type modes() :: :start | :cpu_temp_c | :cpu_temp_f | :cpu_util | :auto

  @type t() :: %__MODULE__{metrics_value: float(), mode: modes()}
  defstruct [metrics_value: 0.0, mode: :cpu_temp_c]
end
