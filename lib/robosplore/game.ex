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

  def bot_command(id, bot_id, command) do
    case :global.whereis_name(id) do
      :undefined -> :not_found
      pid -> GenServer.cast(pid, {:bot_command, bot_id, command})
    end
  end

  def fetch_state(id) do
    case :global.whereis_name(id) do
      :undefined -> :not_found
      pid -> {:ok, GenServer.call(pid, :get_state)}
    end
  end

  # client

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: {:global, id})
  end

  # server

  @impl true
  def init(id) do
    :timer.send_interval(:timer.seconds(1), self(), :tick)
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

  @impl true
  def handle_cast({:bot_command, bot_id, command}, state) do
    state = GameState.bot_command(state, bot_id, command)
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    bot_map = Enum.into(state.bots, %{}, &{&1.id, &1})
    player_map = Enum.into(state.players, %{}, &{&1.id, &1})

    {bot_map, results} =
      state.instructions
      |> Enum.reduce({bot_map, %{}}, fn {bot_id, cmd}, {bots, results} ->
        bot = Map.get(bots, bot_id)
        player = Map.get(player_map, bot.player_id)
        {bot, result} = bot |> apply_instruction(cmd, state.map, player)
        bots = Map.put(bots, bot_id, bot)
        results = Map.put(results, bot_id, result)
        {bots, results}
      end)

    bots = bot_map |> Enum.map(fn {_, bot} -> bot end)
    moved_players = Enum.map(state.instructions, fn {bot_id, _} -> bot_map[bot_id].player_id end)

    players =
      Enum.map(state.players, fn player ->
        if player.id in moved_players do
          Map.put(player, :started, true)
        else
          player
        end
      end)

    state =
      state |> Map.put(:instructions, %{}) |> Map.put(:bots, bots) |> Map.put(:players, players)

    state.bots
    |> Enum.each(fn bot ->
      Phoenix.PubSub.broadcast(
        Robosplore.PubSub,
        "bot:#{state.id}:#{bot.id}",
        {:refresh, Map.get(results, bot.id)}
      )
    end)

    Phoenix.PubSub.broadcast(Robosplore.PubSub, "game:#{state.id}", :refresh)
    {:noreply, state}
  end

  defp apply_instruction(bot, {:move, dir}, map, _) do
    {x, y} = new_pos = move(bot.position, dir)

    cond do
      x < 0 || y < 0 -> {bot, "failed: hit wall"}
      x > map.width || y > map.height -> {bot, "failed: hit wall"}
      Map.get(map.tiles, new_pos) == :water -> {bot, "failed: cannot cross water"}
      true -> {Map.put(bot, :position, new_pos), "success"}
    end
  end

  defp apply_instruction(bot, :mine, map, _) do
    cur_tile = Map.get(map.tiles, bot.position)
    total_inv = bot.inventory |> Enum.map(fn {_, i} -> i end) |> Enum.sum()

    cond do
      cur_tile not in [:iron, :copper, :coal] ->
        {bot, "failed: current tile is not mineable"}

      total_inv >= 10 ->
        {bot, "failed: bot inventory is full"}

      true ->
        inv = Map.update(bot.inventory, cur_tile, 1, &(&1 + 1))
        {Map.put(bot, :inventory, inv), "success"}
    end
  end

  defp apply_instruction(bot, :deposit, _, player) do
    cond do
      bot.inventory == %{} -> {bot, "failed: nothing to deposit"}
      bot.position != player.home -> {bot, "failed: may only deposit resources on home"}
      # TODO:: update player.inventory
      true -> {Map.put(bot, :inventory, %{}), "success"}
    end
  end

  defp apply_instruction(bot, {:build, "BOT"}, _, player) do
    total_iron = player.inventory[:iron]
    total_copper = player.inventory[:copper]
    total_coal = player.inventory[:coal]

    cond do
      bot.position != player.home ->
        {bot, "failed: may only build on home"}

      total_iron < 30 || total_copper < 30 || total_coal < 30 ->
        {bot, "failed: not enough resources. requires 30 each of iron, copper, coal"}

      # TODO:: update player.inventory
      # TODO:: add a bot
      true ->
        {bot, "success"}
    end
  end

  defp move({x, y}, "NORTH"), do: {x, y - 1}
  defp move({x, y}, "SOUTH"), do: {x, y + 1}
  defp move({x, y}, "EAST"), do: {x + 1, y}
  defp move({x, y}, "WEST"), do: {x - 1, y}
end
