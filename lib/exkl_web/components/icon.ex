defmodule ExklWeb.Components.Icon do
  @moduledoc """
  The EXKL droplet icon, rendered live so the digits reflect the real reading.

  The droplet outline and the Elixir-purple -> DeepCool-teal gradient are static.
  Only the number (and unit) inside the bulb change with your telemetry.
  """
  use Phoenix.Component

  @droplet "M100 40 C118 86 154 92 154 132 C154 161.7 129.7 186 100 186 C70.3 186 46 161.7 46 132 C46 92 82 86 100 40 Z"

  attr :id, :string, default: "exkl-icon"
  attr :temp, :any, required: true
  attr :unit, :string, default: "°C"
  attr :size, :integer, default: 48
  attr :theme, :atom, default: :dark, values: [:dark, :light]
  attr :tile, :boolean, default: true
  attr :color_by_temp, :boolean, default: false
  attr :rest, :global

  def exkl_icon(assigns) do
    assigns =
      assigns
      |> assign(:droplet, @droplet)
      |> assign(:gid, "#{assigns.id}-grad")
      |> assign(:tile_fill, if(assigns.theme == :light, do: "#ffffff", else: "#1a1f27"))
      |> assign(:show_digits, assigns.size >= 40)
      |> assign(:digit_color, digit_color(assigns))
      |> assign(:label, format_value(assigns.temp))

    ~H"""
    <svg
      id={@id}
      width={@size}
      height={@size}
      viewBox="0 0 256 256"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={"EXKL #{@label}#{@unit}"}
      data-label={@label}
      data-unit={@unit}
      phx-hook="ExklIcon"
      {@rest}
    >
      <defs>
        <linearGradient id={@gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#4B275F" />
          <stop offset="1" stop-color="#068584" />
        </linearGradient>
      </defs>

      <rect :if={@tile} width="256" height="256" rx="59" fill={@tile_fill} />

      <g transform="translate(128,128) scale(1.075) translate(-100,-113)">
        <path
          d={@droplet}
          fill="none"
          stroke={"url(##{@gid})"}
          stroke-width={if(@show_digits, do: 9, else: 11)}
          stroke-linejoin="round"
          stroke-linecap="round"
        />
        <g :if={@show_digits} font-family="'Bitter', ui-serif, serif" font-weight="700">
          <text x="100" y="138" font-size="42" fill={@digit_color} text-anchor="middle" data-exkl-value>
            {@label}
          </text>
          <text
            :if={@unit != ""}
            x="100"
            y="162"
            font-size="16"
            fill={@digit_color}
            text-anchor="middle"
            letter-spacing="1"
            data-exkl-unit
          >
            {@unit}
          </text>
        </g>
      </g>
    </svg>
    """
  end

  defp format_value(nil), do: "--"
  defp format_value(n) when is_float(n), do: n |> trunc() |> Integer.to_string()
  defp format_value(n) when is_integer(n), do: Integer.to_string(n)
  defp format_value(other), do: to_string(other)

  defp digit_color(%{theme: theme, color_by_temp: false}),
    do: if(theme == :light, do: "#068584", else: "#19a3a0")

  defp digit_color(%{temp: temp}) when not is_number(temp), do: "#19a3a0"
  defp digit_color(%{temp: t}) when t >= 80, do: "#e5484d"
  defp digit_color(%{temp: t}) when t >= 65, do: "#f5a524"
  defp digit_color(%{temp: _}), do: "#19a3a0"
end
