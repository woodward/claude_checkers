defmodule Checkers.Rules do
  @moduledoc """
  Pure functions for validating and computing moves in American Checkers.
  """

  alias Checkers.Board

  @type color :: Board.color()
  @type error ::
          :no_piece_at_source
          | :not_your_piece
          | :destination_occupied
          | :invalid_move
          | :must_continue_jump
          | :jump_available
          | :game_over

  @doc """
  Validates a move within the context of a game, accounting for
  multi-jump chains and mandatory capture.
  """
  @spec validate_game_move(Board.t(), color(), Board.position(), Board.position(), Board.position() | nil) ::
          :ok | {:error, error()}
  def validate_game_move(board, turn, from, to, must_jump_from) do
    cond do
      must_jump_from != nil and from != must_jump_from ->
        {:error, :must_continue_jump}

      must_jump_from != nil ->
        case validate_move(board, turn, from, to) do
          :ok -> if jump?(from, to), do: :ok, else: {:error, :must_continue_jump}
          error -> error
        end

      true ->
        case validate_move(board, turn, from, to) do
          :ok ->
            if not jump?(from, to) and any_jumps_for_color?(board, turn),
              do: {:error, :jump_available},
              else: :ok

          error ->
            error
        end
    end
  end

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

  @doc """
  Returns true if the piece at `pos` has any available jumps.
  """
  @spec any_jumps?(Board.t(), Board.piece(), Board.position()) :: boolean()
  def any_jumps?(%Board{} = board, piece, {row, col} = _pos) do
    jump_targets = [{row + 2, col + 2}, {row + 2, col - 2}, {row - 2, col + 2}, {row - 2, col - 2}]

    Enum.any?(jump_targets, fn to -> valid_jump?(board, piece, {row, col}, to) end)
  end

  @doc """
  Returns true if any piece of the given color has a jump available.
  """
  @spec any_jumps_for_color?(Board.t(), color()) :: boolean()
  def any_jumps_for_color?(%Board{pieces: pieces} = board, turn) do
    Enum.any?(pieces, fn {pos, piece} ->
      color(piece) == turn and any_jumps?(board, piece, pos)
    end)
  end

  @doc """
  Returns true if the given color has any legal move (simple or jump).
  """
  @spec any_legal_moves?(Board.t(), color()) :: boolean()
  def any_legal_moves?(%Board{pieces: pieces} = board, turn) do
    Enum.any?(pieces, fn {pos, piece} ->
      color(piece) == turn and (any_simple_moves?(board, piece, pos) or any_jumps?(board, piece, pos))
    end)
  end

  @doc """
  Returns the list of legal destination positions for the piece at `pos`.

  Respects mandatory capture: if any piece of the same color can jump,
  only jump destinations are returned.
  """
  @spec legal_moves(Board.t(), color(), Board.position()) :: [Board.position()]
  def legal_moves(%Board{} = board, turn, {row, col} = pos) do
    piece = Board.piece_at(board, pos)

    if piece == nil or color(piece) != turn do
      []
    else
      jumps = jump_destinations(board, piece, pos)

      if jumps != [] do
        jumps
      else
        if any_jumps_for_color?(board, turn) do
          # Mandatory capture: another piece can jump, so no simple moves allowed
          []
        else
          simple_destinations(board, piece, {row, col})
        end
      end
    end
  end

  @doc """
  Returns positions of all pieces of the given color that have at least
  one legal move. Respects mandatory capture: if any piece can jump,
  only pieces with jumps are returned.
  """
  @spec movable_pieces(Board.t(), color()) :: [Board.position()]
  def movable_pieces(%Board{pieces: pieces} = board, turn) do
    own_pieces =
      pieces
      |> Enum.filter(fn {_pos, piece} -> color(piece) == turn end)
      |> Enum.map(fn {pos, _piece} -> pos end)

    jumpers =
      Enum.filter(own_pieces, fn pos ->
        piece = Board.piece_at(board, pos)
        any_jumps?(board, piece, pos)
      end)

    if jumpers != [] do
      Enum.sort(jumpers)
    else
      own_pieces
      |> Enum.filter(fn pos ->
        piece = Board.piece_at(board, pos)
        any_simple_moves?(board, piece, pos)
      end)
      |> Enum.sort()
    end
  end

  @doc """
  Returns true if the move from `from` to `to` is a jump (row distance of 2).
  """
  @spec jump?(Board.position(), Board.position()) :: boolean()
  def jump?({from_row, _}, {to_row, _}), do: abs(to_row - from_row) == 2

  @spec jump_destinations(Board.t(), Board.piece(), Board.position()) :: [Board.position()]
  defp jump_destinations(board, piece, {row, col}) do
    [{row + 2, col + 2}, {row + 2, col - 2}, {row - 2, col + 2}, {row - 2, col - 2}]
    |> Enum.filter(fn to -> valid_jump?(board, piece, {row, col}, to) end)
  end

  @spec simple_destinations(Board.t(), Board.piece(), Board.position()) :: [Board.position()]
  defp simple_destinations(board, piece, {row, col}) do
    [{row + 1, col + 1}, {row + 1, col - 1}, {row - 1, col + 1}, {row - 1, col - 1}]
    |> Enum.filter(fn {to_row, to_col} = to ->
      on_board?(to_row, to_col) and valid_simple_move?(piece, {row, col}, to) and Board.piece_at(board, to) == nil
    end)
  end

  @spec any_simple_moves?(Board.t(), Board.piece(), Board.position()) :: boolean()
  defp any_simple_moves?(board, piece, {row, col}) do
    move_targets = [{row + 1, col + 1}, {row + 1, col - 1}, {row - 1, col + 1}, {row - 1, col - 1}]

    Enum.any?(move_targets, fn {to_row, to_col} = to ->
      on_board?(to_row, to_col) and valid_simple_move?(piece, {row, col}, to) and Board.piece_at(board, to) == nil
    end)
  end

  @spec valid_simple_move?(Board.piece(), Board.position(), Board.position()) :: boolean()
  defp valid_simple_move?(_piece, {_from_row, _from_col}, {to_row, to_col}) when to_row not in 0..7 or to_col not in 0..7,
    do: false

  defp valid_simple_move?(piece, {from_row, from_col}, {to_row, to_col}) do
    row_diff = to_row - from_row
    col_diff = abs(to_col - from_col)

    col_diff == 1 and valid_row_direction?(piece, row_diff)
  end

  @spec valid_jump?(Board.t(), Board.piece(), Board.position(), Board.position()) :: boolean()
  defp valid_jump?(board, piece, {from_row, from_col} = from, {to_row, to_col} = to) do
    row_diff = to_row - from_row
    col_diff = to_col - from_col

    if on_board?(to_row, to_col) and abs(col_diff) == 2 and valid_row_direction?(piece, div(row_diff, 2)) do
      mid_piece = Board.piece_at(board, Board.midpoint(from, to))

      mid_piece != nil and color(mid_piece) != color(piece) and Board.piece_at(board, to) == nil
    else
      false
    end
  end

  @spec on_board?(integer(), integer()) :: boolean()
  defp on_board?(row, col), do: row in 0..7 and col in 0..7

  @spec valid_row_direction?(Board.piece(), integer()) :: boolean()
  defp valid_row_direction?(piece, row_diff) when piece in [:dark_king, :light_king], do: row_diff in [-1, 1]
  defp valid_row_direction?(:dark, row_diff), do: row_diff == 1
  defp valid_row_direction?(:light, row_diff), do: row_diff == -1

  defp color(piece), do: Board.color(piece)
end
