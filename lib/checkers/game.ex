defmodule Checkers.Game do
  @moduledoc """
  The checkers game engine.

  Holds the authoritative game state: the board, whose turn it is,
  the game status, and move history.
  """

  alias Checkers.{Board, Rules}

  defstruct board: nil, turn: :dark, status: :playing, moves: []

  @doc """
  Creates a new game with a fresh board. Dark moves first.
  """
  def new do
    %__MODULE__{board: Board.new()}
  end

  @doc """
  Attempts to move a piece from `from` to `to`.
  Returns `{:ok, updated_game}` or `{:error, reason}`.
  """
  def move(%__MODULE__{board: board, turn: turn} = game, from, to) do
    case Rules.validate_move(board, turn, from, to) do
      :ok ->
        {:ok,
         %{game | board: Board.move_piece(board, from, to), turn: next_turn(turn), moves: [{from, to} | game.moves]}}

      {:error, _reason} = error ->
        error
    end
  end

  defp next_turn(:dark), do: :light
  defp next_turn(:light), do: :dark
end
