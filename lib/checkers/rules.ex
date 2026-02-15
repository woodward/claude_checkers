defmodule Checkers.Rules do
  @moduledoc """
  Pure functions for validating and computing moves in American Checkers.
  """

  alias Checkers.Board

  @type color :: :dark | :light
  @type error :: :no_piece_at_source | :not_your_piece | :destination_occupied | :invalid_move

  @doc """
  Validates whether a move from `from` to `to` is legal for the given board and turn.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate_move(Board.t(), color(), Board.position(), Board.position()) :: :ok | {:error, error()}
  def validate_move(%Board{} = board, turn, from, to) do
    piece = Board.piece_at(board, from)

    cond do
      piece == nil ->
        {:error, :no_piece_at_source}

      color(piece) != turn ->
        {:error, :not_your_piece}

      Board.piece_at(board, to) != nil ->
        {:error, :destination_occupied}

      valid_simple_move?(piece, from, to) ->
        :ok

      valid_jump?(board, piece, from, to) ->
        :ok

      true ->
        {:error, :invalid_move}
    end
  end

  @spec valid_simple_move?(Board.piece(), Board.position(), Board.position()) :: boolean()
  defp valid_simple_move?(piece, {from_row, from_col}, {to_row, to_col}) do
    row_diff = to_row - from_row
    col_diff = abs(to_col - from_col)

    col_diff == 1 and valid_row_direction?(piece, row_diff)
  end

  @spec valid_jump?(Board.t(), Board.piece(), Board.position(), Board.position()) :: boolean()
  defp valid_jump?(board, piece, {from_row, from_col}, {to_row, to_col}) do
    row_diff = to_row - from_row
    col_diff = to_col - from_col

    if abs(col_diff) == 2 and valid_row_direction?(piece, div(row_diff, 2)) do
      mid = {from_row + div(row_diff, 2), from_col + div(col_diff, 2)}
      mid_piece = Board.piece_at(board, mid)

      mid_piece != nil and color(mid_piece) != color(piece)
    else
      false
    end
  end

  @spec valid_row_direction?(Board.piece(), integer()) :: boolean()
  defp valid_row_direction?(piece, row_diff) when piece in [:dark_king, :light_king], do: row_diff in [-1, 1]
  defp valid_row_direction?(:dark, row_diff), do: row_diff == 1
  defp valid_row_direction?(:light, row_diff), do: row_diff == -1

  @spec color(Board.piece()) :: color()
  defp color(piece) when piece in [:dark, :dark_king], do: :dark
  defp color(piece) when piece in [:light, :light_king], do: :light
end
