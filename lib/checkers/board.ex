defmodule Checkers.Board do
  @moduledoc """
  Represents an 8x8 American Checkers board.

  Only the 32 dark squares are used. Pieces are stored in a map
  from `{row, col}` positions to piece atoms (`:dark`, `:light`,
  `:dark_king`, `:light_king`).
  """

  defstruct pieces: %{}

  @doc """
  Creates a new board with the standard starting position:
  12 dark pieces on rows 0-2, 12 light pieces on rows 5-7.
  """
  def new do
    pieces =
      for row <- 0..7, col <- 0..7, rem(row + col, 2) == 1, row not in 3..4, into: %{} do
        piece = if row <= 2, do: :dark, else: :light
        {{row, col}, piece}
      end

    %__MODULE__{pieces: pieces}
  end

  @doc """
  Returns the piece at the given `{row, col}` position, or `nil` if empty.
  """
  def piece_at(%__MODULE__{pieces: pieces}, pos) do
    Map.get(pieces, pos)
  end
end
