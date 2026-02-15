defmodule Checkers.Game do
  @moduledoc """
  The checkers game engine.

  Holds the authoritative game state: the board, whose turn it is,
  the game status, and move history.
  """

  alias Checkers.Board

  defstruct board: nil, turn: :dark, status: :playing, moves: []

  @doc """
  Creates a new game with a fresh board. Dark moves first.
  """
  def new do
    %__MODULE__{board: Board.new()}
  end
end
