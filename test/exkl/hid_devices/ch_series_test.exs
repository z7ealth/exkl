defmodule Exkl.HidDevices.ChSeriesTest do
  use ExUnit.Case, async: true

  alias Exkl.AK
  alias Exkl.HidDevices.ChSeries

  describe "encode/1" do
    test "fahrenheit mode converts both CPU and GPU temperatures" do
      packet =
        ChSeries.encode(%AK{
          mode: :cpu_temp_f,
          metrics_value: 109.0,
          gpu_temp_c: 43.0,
          cpu_util: 0.0,
          gpu_util: 0.0
        })

      <<_::8, cpu_mode, _, 1, 0, 9, gpu_mode, _, 1, 0, 9, _::binary>> = packet

      assert cpu_mode == 35
      assert gpu_mode == 35
    end

    test "celsius mode keeps GPU temperature in celsius" do
      packet =
        ChSeries.encode(%AK{
          mode: :cpu_temp_c,
          metrics_value: 43.0,
          gpu_temp_c: 43.0,
          cpu_util: 0.0,
          gpu_util: 0.0
        })

      <<_::8, cpu_mode, _, 0, 4, 3, gpu_mode, _, 0, 4, 3, _::binary>> = packet

      assert cpu_mode == 19
      assert gpu_mode == 19
    end
  end
end
