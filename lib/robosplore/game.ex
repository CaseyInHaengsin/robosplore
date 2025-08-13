defmodule Robosplore.Game do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(opts) do
    {:ok, nil}
  end
end
