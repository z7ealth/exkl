defmodule ExklWeb.TraySparkline do
  @moduledoc false
  use Phoenix.Component

  attr :id, :string, required: true
  attr :values, :list, default: []
  attr :min, :float, default: 0.0
  attr :max, :float, default: 100.0
  attr :width, :integer, default: 280
  attr :height, :integer, default: 48
  attr :class, :string, default: ""
  attr :stroke, :string, default: "currentColor"
  attr :fill, :string, default: "currentColor"

  def tray_sparkline(assigns) do
    points = spark_points(assigns.values, assigns.min, assigns.max, assigns.width, assigns.height)

    assigns =
      assigns
      |> assign(:points, points)
      |> assign(:area, spark_area(points, assigns.width, assigns.height))

    ~H"""
    <svg
      id={@id}
      viewBox={"0 0 #{@width} #{@height}"}
      preserveAspectRatio="none"
      class={["tray-sparkline", @class]}
      aria-hidden="true"
    >
      <polygon
        :if={@area != ""}
        points={@area}
        fill={@fill}
        fill-opacity="0.18"
      />
      <polyline
        :if={@points != ""}
        points={@points}
        fill="none"
        stroke={@stroke}
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  defp spark_points([], _min, _max, _width, _height), do: ""

  defp spark_points(values, min, max, width, height) do
    count = Enum.count(values)
    span = max(max - min, 1.0)

    values
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      x = index / max(count - 1, 1) * width
      y = height - (value - min) / span * height
      "#{Float.round(x, 2)},#{Float.round(y, 2)}"
    end)
    |> Enum.join(" ")
  end

  defp spark_area("", _width, _height), do: ""

  defp spark_area(points, width, height) do
    points <> " #{width},#{height} 0,#{height}"
  end
end
