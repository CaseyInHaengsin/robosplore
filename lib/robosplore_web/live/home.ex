defmodule RobosploreWeb.Home do
  use RobosploreWeb, :live_view
  alias Robosplore.Game

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Robosplore.PubSub, "game_updates")
    {:ok, socket |> assign(:games, Game.list())}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-screen">
      <button phx-click="new-game" class="btn">New Game</button>
      <div class="mt-4">
        <h2 class="text-2xl font-bold">Active Games</h2>
        <ul class="list-disc pl-5">
          <li :for={id <- @games}>
            <span>Game {id}</span>
            <.link class="btn" href={~p"/host/#{id}"}> View </.link>
            <.link class="btn" href={~p"/join/#{id}"}> Join </.link>
            <button phx-click="stop-game" phx-value-id={id} class="btn text-red-500">
              <.icon name="hero-trash" />
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def handle_event("new-game", _params, socket) do
    Game.create()
    Phoenix.PubSub.broadcast(Robosplore.PubSub, "game_updates", :refresh)
    {:noreply, socket}
  end

  def handle_event("stop-game", %{"id" => id}, socket) do
    case Game.stop(id) do
      :ok ->
        Phoenix.PubSub.broadcast(Robosplore.PubSub, "game_updates", :refresh)
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to stop game: #{reason}")}
    end
  end

  def handle_info(:refresh, socket) do
    {:noreply, socket |> assign(:games, Game.list())}
  end
end
