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

  def leave(id, player_id) do
    case :global.whereis_name(id) do
      :undefined -> :not_found
      pid -> GenServer.cast(pid, {:leave, player_id})
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
    :timer.send_interval(300, self(), :tick)
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

  def handle_cast({:leave, player_id}, state) do
    state = GameState.remove_player(state, player_id)
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    bot_map = Enum.into(state.bots, %{}, &{&1.id, &1})
    player_map = Enum.into(state.players, %{}, &{&1.id, &1})

    {{bot_map, player_map}, results} =
      state.instructions
      |> Enum.reduce({{bot_map, player_map}, %{}}, fn {bot_id, cmd}, {{bots, players}, results} ->
        bot = Map.get(bots, bot_id)
        player = Map.get(players, bot.player_id)

        {bot, player, new_bot, result} =
          case apply_instruction(cmd, state.map, bot, player) do
            {:update, {bot, player}} ->
              {bot, player, nil, "success"}

            {:create, {bot, player}} ->
              new_bot = Bot.new(player)
              token = Base.encode64("#{state.id}::#{bot.token}", padding: false)
              {bot, player, new_bot, "success: #{token}"}

            {:error, message} ->
              {bot, player, nil, message}
          end

        bots = if new_bot, do: Map.put(bots, new_bot.id, new_bot), else: bots
        bots = Map.put(bots, bot_id, bot)
        players = Map.put(players, bot.player_id, player)
        results = Map.put(results, bot_id, result)
        {{bots, players}, results}
      end)

    bots = bot_map |> Enum.map(fn {_, bot} -> bot end)
    players = player_map |> Enum.map(fn {_, player} -> player end)

    moved_players = Enum.map(state.instructions, fn {bot_id, _} -> bot_map[bot_id].player_id end)

    players =
      Enum.map(players, fn player ->
        positions =
          bots
          |> Enum.filter(&(&1.player_id == player.id))
          |> Enum.flat_map(&viewable_tiles/1)
          |> MapSet.new()

        player = Map.update!(player, :revealed, &MapSet.union(&1, positions))

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

  defp apply_instruction({:move, dir}, map, bot, player) do
    {x, y} = new_pos = move(bot.position, dir)

    cond do
      x < 0 || y < 0 -> {:error, "failed: hit wall"}
      x >= map.width || y >= map.height -> {:error, "failed: hit wall"}
      Map.get(map.tiles, new_pos) == :water -> {:error, "failed: cannot cross water"}
      true -> {:update, {Map.put(bot, :position, new_pos), player}}
    end
  end

  defp apply_instruction(:mine, map, bot, player) do
    cur_tile = Map.get(map.tiles, bot.position)
    total_inv = bot.inventory |> Enum.map(fn {_, i} -> i end) |> Enum.sum()

    cond do
      cur_tile not in [:iron, :copper, :coal] ->
        {:error, "failed: current tile is not mineable"}

      total_inv >= 10 ->
        {:error, "failed: bot inventory is full"}

      true ->
        inv = Map.update(bot.inventory, cur_tile, 1, &(&1 + 1))
        {:update, {Map.put(bot, :inventory, inv), player}}
    end
  end

  defp apply_instruction(:deposit, _, bot, player) do
    cond do
      bot.inventory.iron + bot.inventory.copper + bot.inventory.coal == 0 ->
        {:error, "failed: nothing to deposit"}

      bot.position != player.home ->
        {:error, "failed: may only deposit resources on home"}

      true ->
        inv =
          player.inventory
          |> Map.update!(:iron, &(&1 + bot.inventory.iron))
          |> Map.update!(:copper, &(&1 + bot.inventory.copper))
          |> Map.update!(:coal, &(&1 + bot.inventory.coal))

        {:update,
         {Map.put(bot, :inventory, %{copper: 0, iron: 0, coal: 0}),
          Map.put(player, :inventory, inv)}}
    end
  end

  defp apply_instruction({:build, "BOT"}, _, bot, player) do
    total_iron = player.inventory.iron
    total_copper = player.inventory.copper
    total_coal = player.inventory.coal

    cond do
      bot.position != player.home ->
        {:error, "failed: may only build on home"}

      total_iron < 30 || total_copper < 30 || total_coal < 30 ->
        {:error, "failed: not enough resources. requires 30 each of iron, copper, coal"}

      true ->
        inv =
          player.inventory
          |> Map.update!(:iron, &(&1 - 30))
          |> Map.update!(:copper, &(&1 - 30))
          |> Map.update!(:coal, &(&1 - 30))

        {:create, {bot, Map.put(player, :inventory, inv)}}
    end
  end

  defp apply_instruction({:color, color}, _, bot, player) do
    {:update, {bot, Map.put(player, :color, color)}}
  end

  defp move({x, y}, "NORTH"), do: {x, y - 1}
  defp move({x, y}, "SOUTH"), do: {x, y + 1}
  defp move({x, y}, "EAST"), do: {x + 1, y}
  defp move({x, y}, "WEST"), do: {x - 1, y}

  defp viewable_tiles(%{position: p}) do
    [p, move(p, "NORTH"), move(p, "SOUTH"), move(p, "EAST"), move(p, "WEST")]
  end
end
