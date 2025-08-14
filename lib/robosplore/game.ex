defmodule Robosplore.Game do
  use GenServer
  alias Robosplore.GameState

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def fetch_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @impl true
  def init(_opts) do
    {:ok, GameState.new()}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
