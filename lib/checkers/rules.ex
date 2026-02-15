defmodule Checkers.Rules do
  @moduledoc """
  Pure functions for validating and computing moves in American Checkers.
  """

  alias Checkers.Board

  @doc """
  Validates whether a move from `from` to `to` is legal for the given board and turn.
  Returns `:ok` or `{:error, reason}`.
  """
  def validate_move(%Board{} = board, turn, from, to) do
    piece = Board.piece_at(board, from)

    cond do
      piece == nil ->
        {:error, :no_piece_at_source}

      color(piece) != turn ->
        {:error, :not_your_piece}

      Board.piece_at(board, to) != nil ->
        {:error, :destination_occupied}

      !valid_simple_move?(piece, from, to) ->
        {:error, :invalid_move}

      true ->
        :ok
    end
  end

  defp valid_simple_move?(piece, {from_row, from_col}, {to_row, to_col}) do
    row_diff = to_row - from_row
    col_diff = abs(to_col - from_col)

    col_diff == 1 and row_diff == forward_direction(piece)
  end

  defp forward_direction(piece) when piece in [:dark, :dark_king], do: 1
  defp forward_direction(piece) when piece in [:light, :light_king], do: -1

  defp color(piece) when piece in [:dark, :dark_king], do: :dark
  defp color(piece) when piece in [:light, :light_king], do: :light
end
