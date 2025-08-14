defmodule RobosploreWeb.GameLive do
  use RobosploreWeb, :live_view

  def mount(%{"pid" => pid}, _session, socket) do
    game_state = Robosplore.Game.fetch_state(str_to_pid(pid))
    {:ok, assign(socket, :game_pid, str_to_pid(pid)) |> assign(:game_state, game_state)}
  end

  def render(assigns) do
    ~H"""
    <div class="game-container">
      <h1>Game PID: {inspect(@game_pid)}</h1>
      <p>Game details will be displayed here.</p>
      <!-- Additional game UI components can be added here -->
      <div class="game-map p-8 flex flex-col gap-4">
        <h2>Game Map</h2>
        <p>Map Width: {@game_state.map.width}, Height: {@game_state.map.height}</p>

        <ul class="relative">
          <li
            :for={{{x, y}, tile} <- @game_state.map.tiles}
            style={"top: #{x * 16}px; left: #{y * 16}px; background-color: #{get_color(tile)};"}
            class="absolute size-4 bg-blue-200"
          >
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp str_to_pid(pid) do
    pid
    |> String.trim_leading("#PID")
    |> to_charlist()
    |> :erlang.list_to_pid()
  end

  # brown
  defp get_color(:iron), do: "#a5a5a5"
  defp get_color(:coal), do: "black"
  defp get_color(:gold), do: "#f3b135"
  defp get_color(:water), do: "#3dacfa"
  defp get_color(:empty), do: "#bfffc2"
end
