defmodule RobosploreWeb.BotSocket do
  use Phoenix.Socket

  channel "bot:*", RobosploreWeb.BotChannel

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
