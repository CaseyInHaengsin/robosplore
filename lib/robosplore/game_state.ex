defmodule GameMap do
  defstruct tiles: %{{0, 0} => :iron}, width: 40, height: 40, buildings: %{}

  def new(width \\ 40, height \\ 40) do
    tiles = for x <- 0..(width - 1), y <- 0..(height - 1), into: %{}, do: {{x, y}, get_tile()}
    %GameMap{tiles: tiles, width: width, height: height}
  end

  defp get_tile() do
    Enum.random([
      :iron,
      :iron,
      :iron,
      :coal,
      :gold,
      :water,
      :water,
      :water,
      :water,
      :water,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty,
      :empty
    ])
  end
end

defmodule Player do
  defstruct id: nil, name: "", inventory: %{}

  def new(id, name) do
    %Player{id: id, name: name}
  end
end

defmodule Bot do
  defstruct id: nil, position: {0, 0}, inventory: %{}

  def new(id) do
    %Bot{id: id}
  end
end

defmodule Robosplore.GameState do
  defstruct map: %GameMap{}, players: [%Player{}], bots: [%Bot{}], instructions: %{}

  def new() do
    %Robosplore.GameState{
      map: GameMap.new(),
      players: [],
      bots: [],
      instructions: %{}
    }
  end
end
