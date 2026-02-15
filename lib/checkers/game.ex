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
  def move(%__MODULE__{must_jump_from: must_jump}, from, _to) when must_jump != nil and from != must_jump do
    {:error, :must_continue_jump}
  end

  def move(%__MODULE__{must_jump_from: must_jump, board: board, turn: turn} = game, from, to)
      when must_jump != nil do
    is_jump = jump?(from, to)

    case Rules.validate_move(board, turn, from, to) do
      :ok when is_jump -> apply_move(game, from, to, true)
      :ok -> {:error, :must_continue_jump}
      {:error, _reason} = error -> error
    end
  end

  def move(%__MODULE__{board: board, turn: turn} = game, from, to) do
    case Rules.validate_move(board, turn, from, to) do
      :ok ->
        if not jump?(from, to) and Rules.any_jumps_for_color?(board, turn) do
          {:error, :jump_available}
        else
          apply_move(game, from, to, jump?(from, to))
        end

      {:error, _reason} = error ->
        error
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
      {:ok,
       %{game | board: new_board, turn: next_turn(turn), must_jump_from: nil, moves: [{from, to} | game.moves]}}
    end
  end

  @spec jump?(Board.position(), Board.position()) :: boolean()
  defp jump?({from_row, _}, {to_row, _}), do: abs(to_row - from_row) == 2

  @spec maybe_remove_captured(Board.t(), Board.position(), Board.position()) :: Board.t()
  defp maybe_remove_captured(board, {from_row, from_col}, {to_row, to_col}) do
    if abs(to_row - from_row) == 2 do
      mid = {div(from_row + to_row, 2), div(from_col + to_col, 2)}
      Board.remove_piece(board, mid)
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
end
