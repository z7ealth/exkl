defmodule Exkl.Display do
  use GenServer

  require Logger

  alias Phoenix.PubSub
  alias Exkl.HidApiNif
  alias Exkl.Ak

  @pubsub_topic "cpu_metrics"

  @vendor_id 0x3633
  @products %{
    ak500: 0x0003,
    ak620: 0x0004
  }
  @display_modes %{
    celsius: 19,
    fahrenheit: 35,
    utilization: 76,
    start: 170
  }

  # Client

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
  # Server (callbacks)

  @impl true
  def init(_params) do
    ak = %Ak{handle: HidApiNif.open(@vendor_id, @products[:ak500])}
    PubSub.subscribe(Exkl.PubSub, @pubsub_topic)

    HidApiNif.write(ak.handle, get_data(0.0, "start"))

    {:ok, ak}
  end

  @impl true
  def handle_info({:cpu_metrics, new_cpu_metrics}, ak) do
    Logger.debug("Exkl.Display received CPU metrics update: #{inspect(new_cpu_metrics)}%")

    HidApiNif.write(ak.handle, get_data(new_cpu_metrics.temp, "temp_c"))

    {:noreply, ak}
  end

  @impl true
  def terminate(reason, ak) do
    Logger.info("Exkl.Display terminating. Closing HID device handle: #{inspect(ak.handle)}. Reason: #{reason}")
    HidApiNif.close(ak)
    :ok
  end

  defp get_bar_value(temp) when temp < 10.0, do: 0.0
  defp get_bar_value(temp), do: temp / 10.0

  def get_data(value, mode) when is_float(value) and is_binary(mode) do
    # Initialize base_data equivalent to `vec![0; 64]`
    # In Elixir, a list of integers works well for Vec<u8>
    base_data = List.duplicate(0, 64)

    # Convert the integer part of the float to a list of its digits
    # Rust: (value as i32).to_string().chars().collect()
    numbers =
      value
      # Convert float to integer (i32 equivalent)
      |> trunc()
      # Convert integer to string
      |> Integer.to_string()
      # Get a list of single-character strings
      |> String.graphemes()
      # Convert each char string to integer (digit)
      |> Enum.map(&String.to_integer/1)

    # base_data[0] = 16;
    # Elixir lists are 0-indexed
    base_data = List.replace_at(base_data, 0, 16)

    # base_data[2] = get_bar_value(value) as u8;
    bar_value = get_bar_value(value) |> trunc()
    base_data = List.replace_at(base_data, 2, bar_value)

    # Match equivalent to Rust's `match mode { ... }`
    base_data =
      case mode do
        # Default case for `DisplayMode::Celsius`
        "start" ->
          List.replace_at(base_data, 1, @display_modes[:start])
        _ ->
          List.replace_at(base_data, 1, @display_modes[:celsius])
      end

    # Handle `numbers.len()` conditions
    result_data =
      cond do
        length(numbers) == 1 ->
          # base_data[5] = numbers[0].to_digit(10).unwrap() as u8;
          List.replace_at(base_data, 5, Enum.at(numbers, 0))

        length(numbers) == 2 ->
          # base_data[4] = numbers[0].to_digit(10).unwrap() as u8;
          # base_data[5] = numbers[1].to_digit(10).unwrap() as u8;
          base_data
          |> List.replace_at(4, Enum.at(numbers, 0))
          |> List.replace_at(5, Enum.at(numbers, 1))

        length(numbers) == 3 ->
          # base_data[3] = numbers[0].to_digit(10).unwrap() as u8;
          # base_data[4] = numbers[1].to_digit(10).unwrap() as u8;
          # base_data[5] = numbers[2].to_digit(10).unwrap() as u8;
          base_data
          |> List.replace_at(3, Enum.at(numbers, 0))
          |> List.replace_at(4, Enum.at(numbers, 1))
          |> List.replace_at(5, Enum.at(numbers, 2))

        # Default case, no changes if length is not 1, 2, or 3
        true ->
          base_data
      end

    # Return the final list
    result_data
    |> :binary.list_to_bin()
  end
end
