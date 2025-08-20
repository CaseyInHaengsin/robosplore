defmodule Robosplore.Game do
  use GenServer
  alias Robosplore.GameState

  # public api

  def create() do
    id = Robosplore.uuid()
    {:ok, _} = DynamicSupervisor.start_child(Robosplore.DynamicSupervisor, {__MODULE__, id})
  end

  def stop(id) do
    pid = :global.whereis_name(id)
    DynamicSupervisor.terminate_child(Robosplore.DynamicSupervisor, pid)
  end

  def list() do
    Robosplore.DynamicSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> GenServer.call(pid, :get_id) end)
  end

  def join(id) do
    case :global.whereis_name(id) do
      :undefined -> :not_found
      pid -> {:ok, GenServer.call(pid, :join)}
    end
  end

  def fetch_state(id) do
    GenServer.call({:global, id}, :get_state)
  end

  # client

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: {:global, id})
  end

  # server

  @impl true
  def init(id) do
    {:ok, GameState.new(id)}
  end

  @impl true
  def handle_call(:get_id, _from, state) do
    {:reply, state.id, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:join, _from, state) do
    {state, player_id} = GameState.add_player(state)
    {:reply, player_id, state}
  end
end
