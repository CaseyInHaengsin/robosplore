defmodule RobosploreWeb.PlayLive do
  use RobosploreWeb, :live_view

  def mount(%{"game_id" => id, "player_id" => pid}, _session, socket) do
    state = Robosplore.Game.fetch_state(id)
    player = state.players |> Enum.find(&(&1.id == pid))
    {:ok, socket |> assign(:state, state) |> assign(:player, player)}
  end

  def render(%{player: %{started: false}} = assigns) do
    ~H"""
    <h1>Welcome to Robosplore!</h1>
    <p>
      This is a game of exploration and mining. You've been given a bot. To start, you'll need to establish a websocket connection to that bot.
    </p>
    <p>Bot Token: <code>{get_bot_token(@state, @player)}</code></p>
    <p>Example Connection Module:</p>
    <pre>
      <code>
        defmodule MyBot do
          use GenServer

          @token "{get_bot_token(@state, @player)}"

          def init(arg) do
            :todo
          end
        end
      </code>
    </pre>
    """
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

  defp get_bot_token(state, player) do
    state.bots
    |> Enum.find(&(&1.player_id == player.id))
    |> Map.get(:token)
  end

  defp get_color(:iron), do: "#a5a5a5"
  defp get_color(:copper), do: "#f3b135"
  defp get_color(:coal), do: "black"
  defp get_color(:water), do: "#3dacfa"
  defp get_color(:empty), do: "#bfffc2"
end
