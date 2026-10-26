defmodule ExklWeb.MetricCard do
  @moduledoc false
  use Phoenix.Component
  use PhoenixPaper.Components

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :value, :string, required: true
  attr :unit, :string, default: ""
  attr :available?, :boolean, default: true
  attr :progress, :float, required: true
  attr :tone, :string, default: "primary", values: ~w(primary tertiary)
  attr :history, :list, default: []
  attr :chart_min, :float, default: 0.0
  attr :chart_max, :float, default: 100.0
  attr :stats, :map, default: %{min: "—", avg: "—", max: "—"}
  attr :icon, :string, required: true
  attr :chart_id, :string, required: true
  attr :value_id, :string, required: true
  attr :freq, :string, default: nil
  attr :power, :string, default: nil

  @segments 24
  @gauge_radius 46
  @gauge_length :math.pi() * @gauge_radius

  def metric_card(assigns) do
    assigns =
      assigns
      |> assign(:segments, @segments)
      |> assign(:gauge_length, @gauge_length)
      |> assign(:gauge_offset, gauge_offset(assigns.progress, @gauge_length))
      |> assign(:gauge_label, gauge_label(assigns.unit))
      |> assign(:active_segments, active_segments(assigns.progress))
      |> assign(:chart_points, chart_points(assigns.history, assigns.chart_min, assigns.chart_max))
      |> assign(:chart_area, chart_area(assigns.history, assigns.chart_min, assigns.chart_max))
      |> assign(:bars, bar_heights(assigns.history, assigns.chart_min, assigns.chart_max))

    ~H"""
    <.pp_card
      variant="elevated"
      class={["metric-card h-full", tone_class(@tone)]}
      content_class="flex flex-col"
    >
      <div class="mb-3 flex items-center justify-between gap-3">
        <div class="flex min-w-0 items-center gap-3">
          <span class="metric-icon-badge flex size-10 shrink-0 items-center justify-center rounded-pp-md">
            <.pp_icon name={@icon} />
          </span>
          <.pp_typography variant="title-medium" tag="h2">{short_title(@title)}</.pp_typography>
        </div>
        <.pp_typography
          variant="body-small"
          tag="p"
          color="on-surface-variant"
          class="metric-subtitle max-w-[55%] truncate text-right"
          title={@subtitle}
        >
          {@subtitle}
        </.pp_typography>
      </div>

      <div class="metric-card-body">
        <div class="dc-gauge" aria-hidden={!@available?}>
          <svg viewBox="0 0 120 72" class="dc-gauge-svg">
            <path
              class="dc-gauge-track"
              d="M 14 68 A 46 46 0 0 1 106 68"
              fill="none"
              pathLength={@gauge_length}
            />
            <path
              class="dc-gauge-fill"
              d="M 14 68 A 46 46 0 0 1 106 68"
              fill="none"
              pathLength={@gauge_length}
              style={"stroke-dasharray: #{@gauge_length}; stroke-dashoffset: #{@gauge_offset}"}
            />
          </svg>
          <div class="dc-gauge-center">
            <.pp_typography variant="label-small" tag="span" color="on-surface-variant">
              {@gauge_label}
            </.pp_typography>
            <span
              class={["dc-gauge-value", !@available? && "metric-unavailable"]}
              phx-hook="MetricPulse"
              id={@value_id}
            >
              {@value}<span :if={@available? && @unit == "%"}>%</span><span :if={@available? && @unit != "%"} class="dc-gauge-unit">{@unit}</span>
            </span>
          </div>
        </div>

        <dl class="flex flex-col justify-center gap-3">
          <div :if={@freq} class="flex flex-col-reverse gap-0.5">
            <dt class="pp-label-medium text-pp-on-surface-variant">Clock speed</dt>
            <dd class="metric-tone pp-title-medium-emphasized">{@freq}</dd>
          </div>
          <div :if={@power} class="flex flex-col-reverse gap-0.5">
            <dt class="pp-label-medium text-pp-on-surface-variant">Power</dt>
            <dd class="metric-tone pp-title-medium-emphasized">{@power}</dd>
          </div>
        </dl>
      </div>

      <div class="metric-chart-wrap">
        <svg viewBox="0 0 240 72" preserveAspectRatio="none" class="metric-chart-svg" aria-hidden="true">
          <defs>
            <linearGradient id={"chart-line-#{@chart_id}"} x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="var(--chart-color-soft)" />
              <stop offset="100%" stop-color="var(--chart-color)" />
            </linearGradient>
            <linearGradient id={"chart-fill-#{@chart_id}"} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="var(--chart-color)" stop-opacity="0.25" />
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

      <div class="mt-3 flex shrink-0 justify-between gap-2 pp-label-medium text-pp-on-surface-variant">
        <span><span class="me-1 uppercase opacity-70">min</span>{@stats.min}</span>
        <span><span class="me-1 uppercase opacity-70">avg</span>{@stats.avg}</span>
        <span><span class="me-1 uppercase opacity-70">max</span>{@stats.max}</span>
      </div>
    </.pp_card>
    """
  end

  defp tone_class("tertiary"), do: "metric-card-tertiary"
  defp tone_class(_), do: nil

  defp short_title("CPU Temperature"), do: "CPU"
  defp short_title("CPU Load"), do: "CPU"
  defp short_title("GPU Temperature"), do: "GPU"
  defp short_title("GPU Load"), do: "GPU"
  defp short_title(title), do: title

  defp gauge_label("%"), do: "Load"
  defp gauge_label("°C"), do: "Temperature"
  defp gauge_label("°F"), do: "Temperature"
  defp gauge_label(_), do: "Metric"

  defp gauge_offset(progress, length) do
    length * (1 - max(0, min(progress, 100)) / 100)
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
      y = invert_y(y, 72)
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
      height |> max(6) |> min(100) |> trunc()
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
