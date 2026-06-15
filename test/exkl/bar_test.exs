defmodule Exkl.BarTest do
  use ExUnit.Case, async: true

  alias Exkl.Bar

  describe "segments/2" do
    test "cpu utilization" do
      assert Bar.segments(0, :cpu_util) == 0
      assert Bar.segments(9, :cpu_util) == 0
      assert Bar.segments(12, :cpu_util) == 1
      assert Bar.segments(40, :cpu_util) == 4
      assert Bar.segments(100, :cpu_util) == 10
    end

    test "cpu utilization edge cases" do
      assert Bar.segments(-5, :cpu_util) == 0
      assert Bar.segments(105, :cpu_util) == 10
      assert Bar.segments(150, :cpu_util) == 10
    end

    test "cpu temperature celsius" do
      assert Bar.segments(0, :cpu_temp_c) == 0
      assert Bar.segments(9, :cpu_temp_c) == 0
      assert Bar.segments(40, :cpu_temp_c) == 4
      assert Bar.segments(100, :cpu_temp_c) == 10
      assert Bar.segments(150, :cpu_temp_c) == 10
      assert Bar.segments(-10, :cpu_temp_c) == 0
    end

    test "cpu temperature fahrenheit uses celsius equivalent" do
      assert Bar.segments(86, :cpu_temp_f) == 3
      assert Bar.segments(212, :cpu_temp_f) == 10
    end

    test "startup mode" do
      assert Bar.segments(99, :start) == 0
    end
  end

  describe "progress/2" do
    test "maps segments to UI percentage" do
      assert Bar.progress(40, :cpu_temp_c) == 40.0
      assert Bar.progress(0, :cpu_util) == 0.0
      assert Bar.progress(100, :cpu_util) == 100.0
      assert Bar.progress(105, :cpu_util) == 100.0
    end
  end
end
