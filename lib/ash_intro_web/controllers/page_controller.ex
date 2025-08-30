defmodule AshIntroWeb.PageController do
  use AshIntroWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
