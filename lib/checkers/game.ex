defmodule Checkers.Game do
  @moduledoc """
  The checkers game engine.

  Holds the authoritative game state: the board, whose turn it is,
  the game status, and move history.
  """

  alias Checkers.{Board, Rules}

  @type status :: :playing | :dark_wins | :light_wins | :draw
  @type t :: %__MODULE__{
          board: Board.t() | nil,
          turn: Rules.color(),
          status: status(),
          moves: [{Board.position(), Board.position()}]
        }

  defstruct board: nil, turn: :dark, status: :playing, moves: []

  @doc """
  Creates a new game with a fresh board. Dark moves first.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{board: Board.new()}
  end

  @doc """
  Attempts to move a piece from `from` to `to`.
  Returns `{:ok, updated_game}` or `{:error, reason}`.
  """
  @spec move(t(), Board.position(), Board.position()) :: {:ok, t()} | {:error, Rules.error()}
  def move(%__MODULE__{board: board, turn: turn} = game, from, to) do
    case Rules.validate_move(board, turn, from, to) do
      :ok ->
        new_board =
          board
          |> Board.move_piece(from, to)
          |> maybe_remove_captured(from, to)

        {:ok, %{game | board: new_board, turn: next_turn(turn), moves: [{from, to} | game.moves]}}

      {:error, _reason} = error ->
        error
    end
  end

  @spec maybe_remove_captured(Board.t(), Board.position(), Board.position()) :: Board.t()
  defp maybe_remove_captured(board, {from_row, from_col}, {to_row, to_col}) do
    if abs(to_row - from_row) == 2 do
      mid = {div(from_row + to_row, 2), div(from_col + to_col, 2)}
      Board.remove_piece(board, mid)
    else
      board
    end
  end

  defp next_turn(:dark), do: :light
  defp next_turn(:light), do: :dark
end
