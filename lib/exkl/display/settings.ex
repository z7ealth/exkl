defmodule Exkl.Display.Settings do
  @moduledoc false

  @pubsub_topic "display_settings"
  @screen_on_key {:exkl, :screen_on}

  @spec screen_on?() :: boolean()
  def screen_on?, do: :persistent_term.get(@screen_on_key, true)

  @spec set_screen_on(boolean()) :: :ok
  def set_screen_on(on) when is_boolean(on) do
    :persistent_term.put(@screen_on_key, on)
    Phoenix.PubSub.broadcast(Exkl.PubSub, @pubsub_topic, {:screen_on, on})
    :ok
  end

  @spec subscribe() :: :ok | {:error, any()}
  def subscribe, do: Phoenix.PubSub.subscribe(Exkl.PubSub, @pubsub_topic)
end
