defmodule Exkl.HidDevice.Behaviour do
  @moduledoc false

  @callback vendor_id() :: non_neg_integer()
  @callback default_product_id() :: non_neg_integer()
  @callback name() :: String.t()
end
