defmodule Exkl.HidDevices.Packet do
  @moduledoc false

  @report_id 16
  @packet_size 64

  @spec blank() :: binary()
  def blank do
    List.duplicate(0, @packet_size)
    |> List.replace_at(0, @report_id)
    |> :binary.list_to_bin()
  end
end
