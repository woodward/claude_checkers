defmodule Checkers.BoardTest do
  use ExUnit.Case, async: true

  alias Checkers.Board

  describe "new/0" do
    test "returns a Board struct" do
      board = Board.new()

      assert %Board{} = board
    end

    test "creates a board with 24 pieces" do
      board = Board.new()

      assert map_size(board.pieces) == 24
    end

    test "places 12 dark pieces on rows 0-2" do
      board = Board.new()

      dark_pieces = for {pos, piece} <- board.pieces, piece == :dark, do: pos
      assert length(dark_pieces) == 12
      assert Enum.all?(dark_pieces, fn {row, _col} -> row in 0..2 end)
    end

    test "places 12 light pieces on rows 5-7" do
      board = Board.new()

      light_pieces = for {pos, piece} <- board.pieces, piece == :light, do: pos
      assert length(light_pieces) == 12
      assert Enum.all?(light_pieces, fn {row, _col} -> row in 5..7 end)
    end

    test "only uses dark squares" do
      board = Board.new()

      assert Enum.all?(board.pieces, fn {{row, col}, _piece} ->
        rem(row + col, 2) == 1
      end)
    end
  end
end
