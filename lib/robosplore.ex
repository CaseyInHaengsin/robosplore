defmodule Robosplore do
  @moduledoc """
  Robosplore keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @alphabet String.graphemes("1234567890abcdef")
  defp c(len), do: Enum.map_join(1..len, fn _ -> Enum.random(@alphabet) end)
  def uuid(), do: "#{c(8)}-#{c(4)}-#{c(4)}-#{c(4)}-#{c(12)}"
end
