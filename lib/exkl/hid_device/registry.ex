defmodule Exkl.HidDevice.Registry do
  @moduledoc false

  alias Exkl.HidDevices.AK500
  alias Exkl.HidDevices.AK620

  @devices [
    %AK500{},
    %AK620{}
  ]

  @spec all() :: [Exkl.HidDevice.t()]
  def all, do: @devices
end
