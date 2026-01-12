defmodule TribunalJurorWeb.PageController do
  use TribunalJurorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
