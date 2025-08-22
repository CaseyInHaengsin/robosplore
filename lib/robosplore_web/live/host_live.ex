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
          :for={%{home: {x, y}, color: color} <- @state.players}
          style={"left: #{x * 16}px; top: #{y * 16}px; background: repeating-linear-gradient(45deg, transparent, transparent 2px, #{color} 2px, #{color} 4px);"}
          class="absolute size-4"
        >
        </li>
        <li
          :for={%{position: {x, y}, player_id: pid} <- @state.bots}
          style={"left: #{x * 16}px; top: #{y * 16}px; background: #{bot_color(@state.players, pid)};"}
          class="absolute size-4 rounded-full border border-2 transition-all"
        >
        </li>
      </ul>
      <div class="pt-[1000px] hidden">
        <label class="font-bold text-sm">Players</label>
        <ul>
          <li :for={player <- @state.players} class="flex gap-2 items-center">
            <span class="size-4 inline-block shrink-0 relative" style={"background: #{player.color};"}>
              <.icon
                :if={player.started}
                name="hero-check"
                class="size-4 absolute top-0 left-0 text-white"
              />
            </span>
            {player.id} {inspect(player.home)}
            {inspect(player.inventory)}
            <button phx-click="kick-player" phx-value-id={player.id} class="btn text-red-500">
              <.icon name="hero-trash" />
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def handle_event("kick-player", %{"id" => id}, socket) do
    Game.leave(socket.assigns.state.id, id)
    {:noreply, socket}
  end

  def handle_info(:refresh, socket) do
    {:ok, state} = Game.fetch_state(socket.assigns.state.id)
    {:noreply, socket |> assign(:state, state)}
  end

  defp bot_color(players, pid) do
    Enum.find(players, &(&1.id == pid)).color
  end

  defp get_color(:iron), do: "#a5a5a5"
  defp get_color(:copper), do: "#f3b135"
  defp get_color(:coal), do: "#555"
  defp get_color(:water), do: "#3dacfa"
  defp get_color(:empty), do: "#bfffc2"
end
