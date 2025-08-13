defmodule RobosploreWeb.PageController do
  use RobosploreWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
