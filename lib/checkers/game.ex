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
          moves: [{Board.position(), Board.position()}],
          must_jump_from: Board.position() | nil
        }

  defstruct board: nil, turn: :dark, status: :playing, moves: [], must_jump_from: nil

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
  def move(%__MODULE__{status: status}, _from, _to) when status != :playing do
    {:error, :game_over}
  end

  def move(%__MODULE__{board: board, turn: turn, must_jump_from: must_jump_from} = game, from, to) do
    case Rules.validate_game_move(board, turn, from, to, must_jump_from) do
      :ok -> apply_move(game, from, to, Rules.jump?(from, to))
      {:error, _reason} = error -> error
    end
  end

  @spec apply_move(t(), Board.position(), Board.position(), boolean()) :: {:ok, t()}
  defp apply_move(%__MODULE__{board: board, turn: turn} = game, from, to, is_jump) do
    new_board =
      board
      |> Board.move_piece(from, to)
      |> maybe_remove_captured(from, to)
      |> maybe_promote(to)

    piece = Board.piece_at(new_board, to)

    if is_jump and Rules.any_jumps?(new_board, piece, to) do
      {:ok, %{game | board: new_board, must_jump_from: to, moves: [{from, to} | game.moves]}}
    else
      next = next_turn(turn)
      status = if Rules.any_legal_moves?(new_board, next), do: :playing, else: winner(turn)

      {:ok,
       %{game | board: new_board, turn: next, status: status, must_jump_from: nil, moves: [{from, to} | game.moves]}}
    end
  end

  @spec maybe_remove_captured(Board.t(), Board.position(), Board.position()) :: Board.t()
  defp maybe_remove_captured(board, {from_row, _} = from, {to_row, _} = to) do
    if abs(to_row - from_row) == 2 do
      Board.remove_piece(board, Board.midpoint(from, to))
    else
      board
    end
  end

  @spec maybe_promote(Board.t(), Board.position()) :: Board.t()
  defp maybe_promote(board, {row, _col} = pos) do
    piece = Board.piece_at(board, pos)

    case {piece, row} do
      {:dark, 7} -> Board.put_piece(board, pos, :dark_king)
      {:light, 0} -> Board.put_piece(board, pos, :light_king)
      _ -> board
    end
  end

  @spec next_turn(Rules.color()) :: Rules.color()
  defp next_turn(:dark), do: :light
  defp next_turn(:light), do: :dark

  @spec winner(Rules.color()) :: status()
  defp winner(:dark), do: :dark_wins
  defp winner(:light), do: :light_wins
end
