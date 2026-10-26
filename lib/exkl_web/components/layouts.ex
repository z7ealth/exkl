defmodule ExklWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use ExklWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layout.app>
      
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="dashboard-bg relative flex h-dvh flex-col overflow-hidden">
      <.pp_top_app_bar id="dashboard-bar" class="dashboard-header shrink-0 px-3 sm:px-5">
        <span class="flex items-center gap-3">
          <span class="live-dot" aria-hidden="true" />
          <.pp_typography variant="label-large" tag="span" color="on-surface-variant" class="uppercase tracking-[0.2em]">
            Live
          </.pp_typography>
        </span>
        <:actions>
          <.pp_theme_toggle id="theme-toggle" />
        </:actions>
      </.pp_top_app_bar>

      <main class="dashboard-main relative z-10 flex flex-1 items-center justify-center overflow-y-auto px-4 py-4 sm:px-6">
        <div class="dashboard-frame mx-auto w-full max-w-6xl">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.pp_flash_group flash={@flash} auto_hide_duration={5000} connection_notices />
    </div>
    """
  end
end
