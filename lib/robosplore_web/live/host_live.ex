defmodule RobosploreWeb.HostLive do
  use RobosploreWeb, :live_view
  alias Robosplore.Game

  def mount(%{"game_id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Robosplore.PubSub, "game:#{id}")

    case Game.fetch_state(id) do
      {:ok, state} -> {:ok, socket |> assign(:state, state)}
      :not_found -> {:ok, socket |> put_flash(:error, "Game Closed") |> redirect(to: ~p"/")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 flex flex-col gap-4">
      <ul class="relative">
        <li
          :for={{{x, y}, tile} <- @state.map.tiles}
          style={"left: #{x * 16}px; top: #{y * 16}px; background-color: #{get_color(tile)};"}
          class="absolute size-4 bg-blue-200"
        >
        </li>
        <li
          :for={%{home: {x, y}} <- @state.players}
          style={"left: #{x * 16}px; top: #{y * 16}px; background: repeating-linear-gradient(45deg, transparent, transparent 2px, red 2px, red 4px);"}
          class="absolute size-4"
        >
        </li>
        <li
          :for={%{position: {x, y}} <- @state.bots}
          style={"left: #{x * 16}px; top: #{y * 16}px; background: red;"}
          class="absolute size-4 rounded-full border border-2 transition-all"
        >
        </li>
      </ul>
    </div>
    """
  end

  def handle_info(:refresh, socket) do
    {:ok, state} = Game.fetch_state(socket.assigns.state.id)
    {:noreply, socket |> assign(:state, state)}
  end

  defp get_color(:iron), do: "#a5a5a5"
  defp get_color(:copper), do: "#f3b135"
  defp get_color(:coal), do: "black"
  defp get_color(:water), do: "#3dacfa"
  defp get_color(:empty), do: "#bfffc2"
end
