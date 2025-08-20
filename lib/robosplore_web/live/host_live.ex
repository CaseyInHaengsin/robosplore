defmodule RobosploreWeb.HostLive do
  use RobosploreWeb, :live_view
  alias Robosplore.Game

  def mount(%{"game_id" => id}, _session, socket) do
    state = Game.fetch_state(id)
    {:ok, socket |> assign(:state, state)}
  end

  def render(assigns) do
    ~H"""
    <div class="game-container">
      <div class="game-map p-8 flex flex-col gap-4">
        <ul class="relative">
          <li
            :for={{{x, y}, tile} <- @state.map.tiles}
            style={"top: #{x * 16}px; left: #{y * 16}px; background-color: #{get_color(tile)};"}
            class="absolute size-4 bg-blue-200"
          >
          </li>
          <li
            :for={%{home: {x, y}} <- @state.players}
            style={"top: #{x * 16}px; left: #{y * 16}px; background: repeating-linear-gradient(45deg, transparent, transparent 2px, red 2px, red 4px);"}
            class="absolute size-4"
          >
          </li>
          <li
            :for={%{position: {x, y}} <- @state.bots}
            style={"top: #{x * 16}px; left: #{y * 16}px; background: red;"}
            class="absolute size-4 rounded-full border border-2"
          >
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp get_color(:iron), do: "#a5a5a5"
  defp get_color(:copper), do: "#f3b135"
  defp get_color(:coal), do: "black"
  defp get_color(:water), do: "#3dacfa"
  defp get_color(:empty), do: "#bfffc2"
end
