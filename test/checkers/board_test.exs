defmodule Checkers.BoardTest do
  use ExUnit.Case, async: true

  alias Checkers.Board

  # Standard starting position used by Board.new/0:
  #
  #     0   1   2   3   4   5   6   7
  # 0 |   | d |   | d |   | d |   | d |
  # 1 | d |   | d |   | d |   | d |   |
  # 2 |   | d |   | d |   | d |   | d |
  # 3 | . |   | . |   | . |   | . |   |
  # 4 |   | . |   | . |   | . |   | . |
  # 5 | l |   | l |   | l |   | l |   |
  # 6 |   | l |   | l |   | l |   | l |
  # 7 | l |   | l |   | l |   | l |   |

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

  describe "piece_at/2" do
    # Uses standard starting position (see diagram above)

    test "returns the piece at an occupied position" do
      board = Board.new()

      # {0,1} is a dark piece, {7,0} is a light piece
      assert Board.piece_at(board, {0, 1}) == :dark
      assert Board.piece_at(board, {7, 0}) == :light
    end

    test "returns nil for an empty position" do
      board = Board.new()

      # {3,0} is an empty dark square in the middle
      assert Board.piece_at(board, {3, 0}) == nil
    end

    test "returns nil for a position off the board" do
      board = Board.new()

      assert Board.piece_at(board, {8, 0}) == nil
    end
  end

  describe "put_piece/3" do
    test "places a piece on an empty square" do
      # Before: empty board
      # After:
      #     0   1   2   3   4   5   6   7
      # 3 | . |   | d |   | . |   | . |   |
      board = %Board{}

      board = Board.put_piece(board, {3, 2}, :dark)

      assert Board.piece_at(board, {3, 2}) == :dark
    end

    test "overwrites an existing piece" do
      # {0,1} starts as :dark, we overwrite with :dark_king
      board = Board.new()

      board = Board.put_piece(board, {0, 1}, :dark_king)

      assert Board.piece_at(board, {0, 1}) == :dark_king
    end
  end

  describe "remove_piece/2" do
    test "removes a piece from the board" do
      # {0,1} starts as :dark in the standard position
      board = Board.new()

      board = Board.remove_piece(board, {0, 1})

      assert Board.piece_at(board, {0, 1}) == nil
    end

    test "is a no-op for an empty square" do
      board = %Board{}

      board = Board.remove_piece(board, {3, 2})

      assert Board.piece_at(board, {3, 2}) == nil
    end
  end

  describe "move_piece/3" do
    test "moves a piece from one position to another" do
      # Using standard position; move dark from {2,1} to {3,2}
      #
      # Before:                          After:
      #     0   1   2   3                    0   1   2   3
      # 2 |   | d |   | d |             2 |   | . |   | d |
      # 3 | . |   | . |   |             3 | . |   | d |   |
      board = Board.new()
      assert Board.piece_at(board, {2, 1}) == :dark
      assert Board.piece_at(board, {3, 2}) == nil

      board = Board.move_piece(board, {2, 1}, {3, 2})

      assert Board.piece_at(board, {2, 1}) == nil
      assert Board.piece_at(board, {3, 2}) == :dark
    end

    test "preserves the piece type" do
      # Custom board with a dark king at {4,3}; move to {3,2}
      #
      # Before:                          After:
      #     0   1   2   3                    0   1   2   3
      # 3 | . |   | . |   |             3 | . |   | D |   |
      # 4 |   | . |   | D |             4 |   | . |   | . |
      board = %Board{} |> Board.put_piece({4, 3}, :dark_king)
      assert Board.piece_at(board, {4, 3}) == :dark_king
      assert Board.piece_at(board, {3, 2}) == nil

      board = Board.move_piece(board, {4, 3}, {3, 2})

      assert Board.piece_at(board, {4, 3}) == nil
      assert Board.piece_at(board, {3, 2}) == :dark_king
    end
  end

  describe "to_list/1" do
    test "returns 64 entries (one per square)" do
      board = Board.new()

      squares = Board.to_list(board)

      assert length(squares) == 64
    end

    test "entries are sorted by row then column" do
      board = Board.new()

      squares = Board.to_list(board)
      positions = Enum.map(squares, fn {pos, _piece} -> pos end)

      expected = for row <- 0..7, col <- 0..7, do: {row, col}
      assert positions == expected
    end

    test "includes pieces at their positions" do
      board = Board.new()

      squares = Board.to_list(board)
      squares_map = Map.new(squares)

      # Dark piece at {0,1}
      assert squares_map[{0, 1}] == :dark
      # Light piece at {7,0}
      assert squares_map[{7, 0}] == :light
      # Empty square at {3,0}
      assert squares_map[{3, 0}] == nil
      # Light square (not playable) at {0,0}
      assert squares_map[{0, 0}] == nil
    end

    test "works with an empty board" do
      board = %Board{}

      squares = Board.to_list(board)

      assert length(squares) == 64
      assert Enum.all?(squares, fn {_pos, piece} -> piece == nil end)
    end
  end
end
