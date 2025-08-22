defmodule GameMap do
  defstruct tiles: %{{0, 0} => :empty}, width: 0, height: 0, buildings: %{}

  def new(width \\ 60, height \\ 60) do
    tiles = for x <- 0..(width - 1), y <- 0..(height - 1), into: %{}, do: {{x, y}, get_tile()}

    %GameMap{
      tiles: tiles,
      width: width,
      height: height
    }
  end

  defp get_tile() do
    case :rand.uniform() do
      a when a < 0.03 -> :iron
      a when a < 0.06 -> :copper
      a when a < 0.09 -> :coal
      a when a < 0.25 -> :water
      _ -> :empty
    end
  end

  def get_starting_loc(map) do
    x = trunc(:rand.uniform() * map.width)
    y = trunc(:rand.uniform() * map.height)

    case Map.get(map.tiles, {x, y}) do
      :empty -> {x, y}
      _ -> get_starting_loc(map)
    end
  end
end

defmodule Player do
  defstruct id: nil,
            home: {0, 0},
            name: "",
            color: "red",
            inventory: %{iron: 0, copper: 0, coal: 0},
            started: false,
            revealed: MapSet.new()

  def new(name, map) do
    %Player{
      id: Robosplore.uuid(),
      name: name,
      home: GameMap.get_starting_loc(map)
    }
  end
end

defmodule Bot do
  defstruct id: nil,
            token: nil,
            player_id: nil,
            position: {0, 0},
            inventory: %{iron: 0, copper: 0, coal: 0}

  def new(player) do
    %Bot{
      id: Robosplore.uuid(),
      token: Robosplore.uuid(),
      player_id: player.id,
      position: player.home
    }
  end
end

defmodule Robosplore.GameState do
  defstruct id: nil, map: %GameMap{}, players: [%Player{}], bots: [%Bot{}], instructions: %{}

  def new(id) do
    %Robosplore.GameState{
      id: id,
      map: GameMap.new(),
      players: [],
      bots: [],
      instructions: %{}
    }
  end

  def add_player(state) do
    player = Player.new("abc", state.map)
    bot = Bot.new(player)

    state = %Robosplore.GameState{
      state
      | players: state.players ++ [player],
        bots: state.bots ++ [bot]
    }

    {state, player.id}
  end

  def remove_player(state, player_id) do
    bot_ids = state.bots |> Enum.filter(&(&1.player_id == player_id)) |> Enum.map(& &1.id)

    %Robosplore.GameState{
      state
      | players: state.players |> Enum.reject(&(&1.id == player_id)),
        bots: state.bots |> Enum.reject(&(&1.player_id == player_id)),
        instructions: Enum.reduce(bot_ids, state.instructions, &Map.delete(&2, &1))
    }
  end

  def bot_command(state, bot_id, command) do
    Map.update!(state, :instructions, &Map.put(&1, bot_id, command))
  end
end
