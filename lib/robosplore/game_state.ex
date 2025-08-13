defmodule GameMap do
  defstruct tiles: %{{0, 0} => :iron}, width: 40, height: 40, buildings: %{}
end

defmodule Player do
  defstruct id: nil, name: "", position: {0, 0}, score: 0

  def new(id, name) do
    %Player{id: id, name: name}
  end
end

defmodule Bot do
  defstruct id: nil, name: "", position: {0, 0}, behavior: :random

  def new(id, name) do
    %Bot{id: id, name: name}
  end
end

defmodule Robosplore.GameState do
  defstruct map: %GameMap{}, players: [%Player{}], bots: [%Bot{}]
end
