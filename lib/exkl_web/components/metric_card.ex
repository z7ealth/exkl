defmodule ExklWeb.MetricCard do
  @moduledoc false
  use Phoenix.Component

  import ExklWeb.CoreComponents

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :value, :string, required: true
  attr :unit, :string, default: ""
  attr :available?, :boolean, default: true
  attr :progress, :float, required: true
  attr :tone, :string, default: "primary"
  attr :history, :list, default: []
  attr :chart_min, :float, default: 0.0
  attr :chart_max, :float, default: 100.0
  attr :stats, :map, default: %{min: "—", avg: "—", max: "—"}
  attr :icon, :string, required: true
  attr :chart_id, :string, required: true
  attr :value_id, :string, required: true

  @segments 24

  def metric_card(assigns) do
    assigns =
      assigns
      |> assign(:segments, @segments)
      |> assign(:active_segments, active_segments(assigns.progress))
      |> assign(:chart_points, chart_points(assigns.history, assigns.chart_min, assigns.chart_max))
      |> assign(:chart_area, chart_area(assigns.history, assigns.chart_min, assigns.chart_max))
      |> assign(:bars, bar_heights(assigns.history, assigns.chart_min, assigns.chart_max))

    ~H"""
    <section class={["glass-panel metric-card", "metric-card-#{@tone}"]}>
      <div class="metric-card-header">
        <div class="min-w-0">
          <p class="metric-label">{@title}</p>
          <p class="metric-subtitle">{@subtitle}</p>
        </div>
        <div class={["metric-icon-badge", @tone == "accent" && "metric-icon-badge-accent"]}>
          <.icon
            name={@icon}
            class={"size-5 sm:size-6 #{if(@tone == "accent", do: "text-accent", else: "text-primary")}"}
          />
        </div>
      </div>

      <div class="metric-card-value-row">
        <div class="metric-card-value">
          <span
            class={["metric-number", !@available? && "metric-unavailable"]}
            phx-hook="MetricPulse"
            id={@value_id}
          >
            {@value}
          </span>
          <span :if={@available?} class="metric-unit">{@unit}</span>
        </div>

        <div class="metric-meter" aria-hidden="true">
          <div class="metric-meter-track">
            <div class="metric-meter-fill" style={"width: #{@progress}%"} />
          </div>
          <div class="metric-segments">
            <span
              :for={i <- 1..@segments}
              class={["metric-seg", i <= @active_segments && "metric-seg-on"]}
            />
          </div>
        </div>
      </div>

      <div class="metric-chart-wrap">
        <svg viewBox="0 0 240 72" preserveAspectRatio="none" class="metric-chart-svg" aria-hidden="true">
          <defs>
            <linearGradient id={"chart-line-#{@chart_id}"} x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="var(--chart-color-soft)" />
              <stop offset="100%" stop-color="var(--chart-color)" />
            </linearGradient>
            <linearGradient id={"chart-fill-#{@chart_id}"} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="var(--chart-color)" stop-opacity="0.35" />
              <stop offset="100%" stop-color="var(--chart-color)" stop-opacity="0" />
            </linearGradient>
          </defs>
          <line x1="0" y1="18" x2="240" y2="18" class="metric-chart-grid-line" />
          <line x1="0" y1="36" x2="240" y2="36" class="metric-chart-grid-line" />
          <line x1="0" y1="54" x2="240" y2="54" class="metric-chart-grid-line" />
          <polygon
            :if={@chart_area != ""}
            class="metric-chart-area"
            points={@chart_area}
            fill={"url(#chart-fill-#{@chart_id})"}
          />
          <polyline
            :if={@chart_points != ""}
            class="metric-chart-line"
            points={@chart_points}
            fill="none"
            stroke={"url(#chart-line-#{@chart_id})"}
          />
        </svg>

        <div class="metric-bars" aria-hidden="true">
          <span
            :for={{bar, idx} <- Enum.with_index(@bars)}
            class="metric-bar"
            style={"height: #{bar}%; animation-delay: #{idx * 12}ms"}
          />
        </div>
      </div>

      <div class="metric-stats">
        <span><em>min</em> {@stats.min}</span>
        <span><em>avg</em> {@stats.avg}</span>
        <span><em>max</em> {@stats.max}</span>
      </div>
    </section>
    """
  end

  defp active_segments(progress) do
    progress
    |> max(0)
    |> min(100)
    |> Kernel.*(@segments / 100)
    |> round()
  end

  defp chart_points([], _min, _max), do: ""

  defp chart_points(values, min, max) do
    count = Enum.count(values)

    values
    |> normalize_series(min, max, 72)
    |> Enum.with_index()
    |> Enum.map(fn {y, index} ->
      x = index / max(count - 1, 1) * 240
      "#{Float.round(x, 2)},#{Float.round(y, 2)}"
    end)
    |> Enum.join(" ")
  end

  defp chart_area([], _min, _max), do: ""

  defp chart_area(values, min, max) do
    line = chart_points(values, min, max)

    if line == "" do
      ""
    else
      line <> " 240,72 0,72"
    end
  end

  defp bar_heights([], _min, _max), do: List.duplicate(4, @segments)

  defp bar_heights(values, min, max) do
    values
    |> pad_series(@segments)
    |> normalize_series(min, max, 100)
    |> Enum.map(fn height ->
      height |> invert_y(100) |> max(6) |> min(100) |> trunc()
    end)
  end

  defp pad_series(values, size) do
    padding = max(size - Enum.count(values), 0)

    if padding > 0 do
      List.duplicate(Enum.at(values, 0, 0), padding) ++ values
    else
      Enum.take(values, -size)
    end
  end

  defp normalize_series(values, min, max, height) do
    span = max(max - min, 1.0)

    Enum.map(values, fn value ->
      (value - min) / span * height
    end)
  end

  defp invert_y(y, height), do: height - y
end
