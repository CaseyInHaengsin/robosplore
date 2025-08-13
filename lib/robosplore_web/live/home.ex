defmodule RobosploreWeb.Home do
  use RobosploreWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Robosplore.PubSub, "game_updates")
    end

    {:ok,
     socket |> assign(:games, DynamicSupervisor.which_children(Robosplore.DynamicSupervisor))}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-screen">
      <button phx-click="new-game" class="btn">New Game</button>
      <div class="mt-4">
        <h2 class="text-2xl font-bold">Active Games</h2>
        <ul class="list-disc pl-5">
          <li :for={{_, pid, _type, _modules} <- @games}>
            <span>Game PID: {inspect(pid)}</span>
            <button phx-click="stop-game" phx-value-pid={inspect(pid)} class="btn btn-danger ml-2">
              Stop
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def handle_event("new-game", _params, socket) do
    {:ok, _} =
      DynamicSupervisor.start_child(
        Robosplore.DynamicSupervisor,
        {Robosplore.Game, [{"key", "value"}]}
      )

    Phoenix.PubSub.broadcast(Robosplore.PubSub, "game_updates", :get_children)

    {:noreply, socket}
  end

  def handle_event("stop-game", %{"pid" => pid}, socket) do
    case DynamicSupervisor.terminate_child(
           Robosplore.DynamicSupervisor,
           str_to_pid(pid)
         ) do
      :ok ->
        Phoenix.PubSub.broadcast(Robosplore.PubSub, "game_updates", :get_children)
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to stop game: #{reason}")}
    end
  end

  def handle_info(:get_children, socket) do
    {:noreply,
     socket |> assign(:games, DynamicSupervisor.which_children(Robosplore.DynamicSupervisor))}
  end

  defp str_to_pid(pid) do
    pid
    |> String.trim_leading("#PID")
    |> to_charlist()
    |> :erlang.list_to_pid()
  end
end
