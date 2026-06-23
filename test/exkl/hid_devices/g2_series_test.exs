defmodule Exkl.HidDevices.G2SeriesTest do
  use ExUnit.Case, async: true

  alias Exkl.AK
  alias Exkl.HidDevices.G2Series

  describe "encode/1" do
    test "startup packet is 64 bytes and does not crash with default metrics" do
      packet = G2Series.startup()

      assert byte_size(packet) == 64
      assert <<16, 104, 1, 8, 12, 1, 2, _::binary>> = packet
    end

    test "blank packet is a valid zero-metrics report" do
      packet = G2Series.blank()

      assert byte_size(packet) == 64
      assert <<16, 104, 1, 8, 12, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 22, _::binary>> =
               packet

      assert packet == G2Series.startup()
    end

    test "off packet clears the display with D6 set to 0" do
      packet = G2Series.off()

      assert byte_size(packet) == 64
      assert <<16, 104, 1, 8, 12, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 126, 22, _::binary>> =
               packet
    end

    test "celsius temperature is encoded as a 32-bit float" do
      packet =
        G2Series.encode(%AK{
          mode: :cpu_temp_c,
          metrics_value: 45.5,
          cpu_temp_c: 45.5,
          cpu_util: 42.0,
          cpu_freq_mhz: 3600.0,
          cpu_power_w: 12.5
        })

      assert byte_size(packet) == 64

      assert <<16, 104, 1, 8, 12, 1, 2, 0, 13, 0, 66, 54, 0, 0, 42, 14, 16, _::binary>> =
               packet
    end

    test "power is encoded in watts, not milliwatts" do
      packet = G2Series.encode(%AK{cpu_power_w: 80.0, cpu_util: 0.0})

      assert <<16, 104, 1, 8, 12, 1, 2, 0, 80, _::binary>> = packet
    end

    test "fahrenheit mode sends fahrenheit temperature with unit flag" do
      packet =
        G2Series.encode(%AK{
          mode: :cpu_temp_f,
          metrics_value: 98.6,
          cpu_temp_c: 37.0,
          cpu_util: 0.0
        })

      assert <<16, 104, 1, 8, 12, 1, 2, 0, 0, 1, 66, 197, 51, 51, 0, 0, 0, _::binary>> =
               packet
    end

    test "util mode still encodes cpu temperature, not utilization" do
      packet =
        G2Series.encode(%AK{
          mode: :cpu_util,
          metrics_value: 42.0,
          cpu_temp_c: 36.0,
          cpu_util: 42.0
        })

      assert <<16, 104, 1, 8, 12, 1, 2, 0, 0, 0, 66, 16, 0, 0, 42, 0, 0, _::binary>> = packet
    end
  end
end
