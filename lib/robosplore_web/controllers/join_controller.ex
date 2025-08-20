defmodule RobosploreWeb.JoinController do
  use RobosploreWeb, :controller
  alias Robosplore.Game

  def join(conn, %{"game_id" => id}) do
    case Game.join(id) do
      {:ok, player_id} -> conn |> redirect(to: "/play/#{id}/#{player_id}")
      :not_found -> conn |> send_resp(404, "Not Found")
    end
  end
end
