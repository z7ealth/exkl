defmodule ExklWeb.PageController do
  use ExklWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
