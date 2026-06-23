defprotocol Exkl.HidDevice do
  @moduledoc """
  Encodes application metrics into HID payloads for a specific device model.
  """

  @doc "USB vendor ID used to open the HID device."
  def vendor_id(device)

  @doc "USB product ID used to open the HID device."
  def product_id(device)

  @doc "Human-readable device name for logging."
  def name(device)

  @doc "Payload sent once when the device is connected."
  def startup_payload(device)

  @doc "Payload sent to power down the HID display when the screen is turned off."
  def off_payload(device)

  @doc "Payload sent to clear the HID display when the screen is turned off."
  def blank_payload(device)

  @doc "Encodes the latest metrics snapshot for the HID display."
  def encode_metrics(device, metrics)
end
