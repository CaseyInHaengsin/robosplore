defmodule RobosploreWeb.BotChannel do
  use Phoenix.Channel
  require Logger
  alias Robosplore.Game

  def join("bot:" <> token, _payload, socket) do
    case parse_token(token) do
      {:ok, {gid, bid}} ->
        Phoenix.PubSub.subscribe(Robosplore.PubSub, "bot:#{gid}:#{bid}")
        {:ok, socket |> assign(game_id: gid) |> assign(bot_id: bid)}

      :malformed ->
        {:error, %{reason: "bot token malformed"}}

      :no_game ->
        {:error, %{reason: "game not found"}}

      :no_bot ->
        {:error, %{reason: "bot not found"}}
    end
  end

  defp parse_token(token) do
    with {:ok, str} <- Base.decode64(token, padding: false),
         [game_id, bot_token] <- String.split(str, "::"),
         {:ok, state} <- Robosplore.Game.fetch_state(game_id),
         %{} = bot <- Enum.find(state.bots, &(&1.token == bot_token)) do
      {:ok, {game_id, bot.id}}
    else
      :not_found -> :no_game
      nil -> :no_bot
      _ -> :malformed
    end
  end

  def handle_info({:refresh, prev}, socket) do
    {:ok, state} = Game.fetch_state(socket.assigns.game_id)
    %{position: {x, y}} = state.bots |> Enum.find(&(&1.id == socket.assigns.bot_id))

    push(socket, "tick", %{
      curr: Map.get(state.map.tiles, {x, y}, :wall),
      west: Map.get(state.map.tiles, {x - 1, y}, :wall),
      north: Map.get(state.map.tiles, {x, y - 1}, :wall),
      east: Map.get(state.map.tiles, {x + 1, y}, :wall),
      south: Map.get(state.map.tiles, {x, y + 1}, :wall),
      prev: prev
    })

    {:noreply, socket}
  end

  def handle_in("next", payload, socket) do
    case parse_command(payload) do
      {:ok, command} ->
        Game.bot_command(socket.assigns.game_id, socket.assigns.bot_id, command)
        {:reply, {:ok, "√"}, socket}

      {:error, message} ->
        {:reply, {:error, message}, socket}
    end
  end

  def handle_in(event, payload, socket) do
    Logger.warning("unhandled event #{event} #{inspect(payload)}")
    {:noreply, socket}
  end

  defp parse_command(payload) do
    case payload do
      %{"cmd" => "MOVE", "dir" => dir} when dir in ["NORTH", "SOUTH", "EAST", "WEST"] ->
        {:ok, {:move, dir}}

      %{"cmd" => "MOVE", "dir" => dir} ->
        {:error,
         "Unknown move direction: #{inspect(dir)}. Valid directions are: NORTH SOUTH EAST WEST"}

      %{"cmd" => "MOVE"} ->
        {:error, "Move command is missing a direction (dir)"}

      %{"cmd" => "MINE"} ->
        {:ok, :mine}

      %{"cmd" => "DEPOSIT"} ->
        {:ok, :deposit}

      %{"cmd" => "BUILD", "recipe" => recipe} when recipe in ["BOT"] ->
        {:ok, {:build, recipe}}

      %{"cmd" => "BUILD", "recipe" => recipe} ->
        {:error, "Unknown build recipe: #{inspect(recipe)}. Valid recipes are: BOT"}

      %{"cmd" => "BUILD"} ->
        {:error, "Build command is missing a recipe"}

      %{"cmd" => "COLOR", "color" => color} when is_binary(color) ->
        if Regex.match?(~r/#[0-9A-Fa-f]{6}/, color) do
          {:ok, {:color, color}}
        else
          {:error, "Color command expects a hex color (i.e. #ff8100)"}
        end

      %{"cmd" => "COLOR"} ->
        {:error, "Color command is missing a hex color (i.e. #ff8100)"}

      %{"cmd" => cmd} ->
        {:error,
         "Unknown command: #{inspect(cmd)}. Valid commands are: MOVE MINE DEPOSIT BUILD COLOR"}

      _ ->
        {:error, "Message must contain a cmd"}
    end
  end
end
