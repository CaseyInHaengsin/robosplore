defmodule RobosploreWeb.PlayLive do
  use RobosploreWeb, :live_view
  alias Robosplore.Game

  @example_code """
  defmodule Bot do
    alias Phoenix.Channels.GenSocketClient

    @url "{{HOST}}/bot/websocket"
    @token "{{TOKEN}}"
    @topic "bot:\#{@token}"

    def start_link() do
      GenSocketClient.start_link(__MODULE__, GenSocketClient.Transport.WebSocketClient, @url)
    end

    def init(url), do: {:connect, url, [], %{}}

    def handle_connected(transport, state) do
      {:ok, _} = GenSocketClient.join(transport, @topic)
      {:ok, state}
    end

    def handle_message(_topic, "tick", payload, transport, state) do
      IO.inspect("message from server: \#{inspect(payload)}")
      dir = Enum.random(["NORTH", "SOUTH", "WEST", "EAST"])
      GenSocketClient.push(transport, @topic, "next", %{cmd: "MOVE", dir: dir})
      {:ok, state}
    end

    def handle_joined(_topic, _payload, _transport, state), do: {:ok, state}

    def handle_join_error(_topic, payload, _transport, state) do
      IO.inspect("join error: \#{inspect(payload)}")
      {:ok, state}
    end

    def handle_reply(_topic, _ref, payload, _transport, state) do
      IO.inspect("reply from server: \#{inspect(payload)}")
      {:ok, state}
    end
  end
  """

  def mount(%{"game_id" => id, "player_id" => pid}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Robosplore.PubSub, "game:#{id}")

    case Robosplore.Game.fetch_state(id) do
      {:ok, state} ->
        player = state.players |> Enum.find(&(&1.id == pid))
        {:ok, socket |> assign(:state, state) |> assign(:pid, pid) |> assign(:player, player)}

      :not_found ->
        {:ok, socket |> put_flash(:error, "Game Closed") |> redirect(to: ~p"/")}
    end
  end

  def render(%{player: %{started: false}} = assigns) do
    assigns = assigns |> assign(:example_code, @example_code)

    ~H"""
    <div class="px-20 py-10">
      <h1 class="text-center text-2xl">Welcome to Robosplore!</h1>
      <p class="text-center max-w-[600px] py-4 mx-auto">
        This is a game of exploration and mining. You've been given a bot. To start, you'll need to establish a websocket connection to that bot. This page will update once you've connected and sent your first message.
      </p>
      <p class="text-center">
        <span class="font-bold">Bot Token:</span>
        <code class="p-1 bg-gray-200">{get_bot_token(@state, @player)}</code>
      </p>
      <p class="text-sm font-bold text-center pt-10">Example Connection Module:</p>
      <div class="flex flex-col gap-4">
        <p>First run</p>
        <pre class="bg-gray-200 p-4">mix new robosplore-client --sup --module Bot --app bot</pre>
        <p>Then add these to your mix.exs deps</p>
        <pre class="bg-gray-200 p-4">
    &lbrace;:phoenix_gen_socket_client, "~> 4.0"},
    &lbrace;:websocket_client, "~> 1.2"},
    &lbrace;:jason, "~> 1.1"}</pre>
        <p>And replace bot.exs with this:</p>
        <pre class="bg-gray-200 p-4">{@example_code |> String.replace("{{TOKEN}}", get_bot_token(@state, @player)) |> String.replace("{{HOST}}", "ws://localhost:4000")}</pre>
        <p>
          Now you're ready to <code class="p-1 bg-gray-200">mix deps.get</code>, <code class="p-1 bg-gray-200">iex -S mix</code>, and
          <code class="p-1 bg-gray-200">Bot.start_link()</code>
        </p>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
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
      <div class="absolute top-8 right-8 w-[500px] bg-gray-300 p-8">
        <label class="font-bold text-sm">Inventory</label>
        <ul>
          <li>Iron: {@player.inventory[:iron] || 0}</li>
          <li>Copper: {@player.inventory[:copper] || 0}</li>
          <li>Coal: {@player.inventory[:coal] || 0}</li>
        </ul>

        <label class="font-bold text-sm pt-6 block">Bots</label>
        <ol>
          <li
            :for={bot <- @state.bots |> Enum.filter(&(&1.player_id == @player.id))}
            class="break-all list-decimal"
          >
            {get_bot_token(@state, @player, bot)}
          </li>
        </ol>

        <label class="font-bold text-sm pt-6 block">Valid Commands</label>
        <ul>
          <li>%&lbrace;cmd: "MOVE", dir: "NORTH | WEST | SOUTH | EAST" }</li>
          <li>%&lbrace;cmd: "MINE" }</li>
          <li>%&lbrace;cmd: "DEPOSIT" }</li>
          <li>%&lbrace;cmd: "BUILD", recipe: "BOT" }</li>
        </ul>
      </div>
    </div>
    """
  end

  def handle_info(:refresh, socket) do
    {:ok, state} = Game.fetch_state(socket.assigns.state.id)
    player = state.players |> Enum.find(&(&1.id == socket.assigns.pid))
    {:noreply, socket |> assign(:state, state) |> assign(:player, player)}
  end

  defp get_bot_token(state, player) do
    bot = state.bots |> Enum.find(&(&1.player_id == player.id))
    get_bot_token(state, player, bot)
  end

  defp get_bot_token(state, _player, bot) do
    token = bot |> Map.get(:token)
    Base.encode64("#{state.id}::#{token}", padding: false)
  end

  defp get_color(:iron), do: "#a5a5a5"
  defp get_color(:copper), do: "#f3b135"
  defp get_color(:coal), do: "black"
  defp get_color(:water), do: "#3dacfa"
  defp get_color(:empty), do: "#bfffc2"
end
