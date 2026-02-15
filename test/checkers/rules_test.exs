defmodule Checkers.RulesTest do
  use ExUnit.Case, async: true

  alias Checkers.{Board, Rules}

  describe "validate_move/4 - simple moves" do
    test "allows a dark checker to move diagonally forward" do
      board = Board.new()

      assert :ok = Rules.validate_move(board, :dark, {2, 1}, {3, 2})
      assert :ok = Rules.validate_move(board, :dark, {2, 1}, {3, 0})
    end

    test "allows a light checker to move diagonally forward" do
      board = Board.new()

      assert :ok = Rules.validate_move(board, :light, {5, 0}, {4, 1})
      assert :ok = Rules.validate_move(board, :light, {5, 2}, {4, 1})
    end

    test "rejects moving from an empty square" do
      board = Board.new()
      assert Board.piece_at(board, {3, 0}) == nil

      assert {:error, :no_piece_at_source} = Rules.validate_move(board, :dark, {3, 0}, {4, 1})
    end

    test "rejects moving the opponent's piece" do
      board = Board.new()
      assert Board.piece_at(board, {5, 0}) == :light

      assert {:error, :not_your_piece} = Rules.validate_move(board, :dark, {5, 0}, {4, 1})
    end

    test "rejects moving to an occupied square" do
      board = Board.new()
      assert Board.piece_at(board, {1, 2}) != nil

      assert {:error, :destination_occupied} = Rules.validate_move(board, :dark, {2, 1}, {1, 2})
    end

    test "rejects a checker moving backward" do
      board = %Board{} |> Board.put_piece({3, 2}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {3, 2}, {2, 1})
    end

    test "rejects moving more than one square" do
      board = %Board{} |> Board.put_piece({2, 1}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {2, 1}, {4, 3})
    end

    test "rejects moving sideways" do
      board = %Board{} |> Board.put_piece({3, 2}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {3, 2}, {3, 3})
    end
  end

  describe "validate_move/4 - jumps" do
    test "allows a dark checker to jump over a light checker" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)

      assert Board.piece_at(board, {4, 3}) == nil

      assert :ok = Rules.validate_move(board, :dark, {2, 1}, {4, 3})
    end

    test "allows a light checker to jump over a dark checker" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | d |   | . |   | . |
      # 5 | . |   | . |   | l |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({5, 4}, :light)
        |> Board.put_piece({4, 3}, :dark)

      assert Board.piece_at(board, {3, 2}) == nil

      assert :ok = Rules.validate_move(board, :light, {5, 4}, {3, 2})
    end

    test "rejects jumping over an empty square" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)

      assert Board.piece_at(board, {3, 2}) == nil

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {2, 1}, {4, 3})
    end

    test "rejects jumping over your own piece" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | d |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {2, 1}, {4, 3})
    end

    test "rejects jumping to an occupied landing square" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | l |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)
        |> Board.put_piece({4, 3}, :light)

      assert {:error, :destination_occupied} = Rules.validate_move(board, :dark, {2, 1}, {4, 3})
    end

    test "rejects a checker jumping backward" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | d |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({4, 3}, :dark)
        |> Board.put_piece({3, 2}, :light)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {4, 3}, {2, 1})
    end
  end

  describe "validate_move/4 - king moves" do
    test "dark king can move forward" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | D |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({4, 3}, :dark_king)

      assert :ok = Rules.validate_move(board, :dark, {4, 3}, {5, 4})
      assert :ok = Rules.validate_move(board, :dark, {4, 3}, {5, 2})
    end

    test "dark king can move backward" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | D |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({4, 3}, :dark_king)

      assert :ok = Rules.validate_move(board, :dark, {4, 3}, {3, 4})
      assert :ok = Rules.validate_move(board, :dark, {4, 3}, {3, 2})
    end

    test "light king can move backward (forward for dark)" do
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | L |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({4, 3}, :light_king)

      assert :ok = Rules.validate_move(board, :light, {4, 3}, {5, 4})
      assert :ok = Rules.validate_move(board, :light, {4, 3}, {5, 2})
    end

    test "dark king can jump backward over a light piece" do
      # Dark king at {4,3} jumps backward over light at {3,2}, lands at {2,1}
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | D |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({4, 3}, :dark_king)
        |> Board.put_piece({3, 2}, :light)

      assert Board.piece_at(board, {2, 1}) == nil

      assert :ok = Rules.validate_move(board, :dark, {4, 3}, {2, 1})
    end

    test "light king can jump backward over a dark piece" do
      # Light king at {3,2} jumps backward (downward) over dark at {4,3}, lands at {5,4}
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | L |   | . |   | . |   |
      # 4 |   | . |   | d |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({3, 2}, :light_king)
        |> Board.put_piece({4, 3}, :dark)

      assert Board.piece_at(board, {5, 4}) == nil

      assert :ok = Rules.validate_move(board, :light, {3, 2}, {5, 4})
    end
  end

  describe "validate_move/4 - board boundaries" do
    test "rejects a jump that would land off the board" do
      # Dark at {0,1} has light at {1,0} to jump over, but landing {2,-1} is off the board
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | d |   | . |   | . |   | . |
      # 1 | l |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({0, 1}, :dark)
        |> Board.put_piece({1, 0}, :light)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {0, 1}, {2, -1})
    end

    test "any_jumps? returns false when all jumps would land off the board" do
      # Dark at {0,1} has light at {1,0}, but the only jump lands at {2,-1} (off board)
      # The other direction {1,2} has no piece to jump over
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | d |   | . |   | . |   | . |
      # 1 | l |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({0, 1}, :dark)
        |> Board.put_piece({1, 0}, :light)

      refute Rules.any_jumps?(board, :dark, {0, 1})
    end

    test "rejects a simple move off the bottom of the board" do
      # Dark at {7,6} tries to move to {8,7} — off the board
      #
      #     0   1   2   3   4   5   6   7
      # 7 | . |   | . |   | . |   | d |   |
      board = %Board{} |> Board.put_piece({7, 6}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {7, 6}, {8, 7})
    end

    test "rejects a simple move off the top of the board" do
      # Light at {0,1} tries to move to {-1,0} — off the board
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | l |   | . |   | . |   | . |
      board = %Board{} |> Board.put_piece({0, 1}, :light)

      assert {:error, :invalid_move} = Rules.validate_move(board, :light, {0, 1}, {-1, 0})
    end

    test "rejects a simple move off the right of the board" do
      # Dark at {2,7} tries to move to {3,8} — off the board
      #
      #     0   1   2   3   4   5   6   7
      # 2 |   | . |   | . |   | . |   | d |
      board = %Board{} |> Board.put_piece({2, 7}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {2, 7}, {3, 8})
    end

    test "rejects a simple move off the left of the board" do
      # Light at {5,0} tries to move to {4,-1} — off the board
      #
      #     0   1   2   3   4   5   6   7
      # 5 | l |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({5, 0}, :light)

      assert {:error, :invalid_move} = Rules.validate_move(board, :light, {5, 0}, {4, -1})
    end

    test "rejects a jump landing beyond row 7" do
      # Dark at {6,5} with light at {7,6} — jump would land at {8,7}
      #
      #     0   1   2   3   4   5   6   7
      # 6 |   | . |   | . |   | d |   | . |
      # 7 | . |   | . |   | . |   | l |   |
      board =
        %Board{}
        |> Board.put_piece({6, 5}, :dark)
        |> Board.put_piece({7, 6}, :light)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {6, 5}, {8, 7})
    end

    test "rejects a jump landing below row 0" do
      # Light at {1,2} with dark at {0,1} — jump would land at {-1,0}
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | d |   | . |   | . |   | . |
      # 1 | . |   | l |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({1, 2}, :light)
        |> Board.put_piece({0, 1}, :dark)

      assert {:error, :invalid_move} = Rules.validate_move(board, :light, {1, 2}, {-1, 0})
    end

    test "rejects a jump landing beyond col 7" do
      # Dark at {2,7} with light at {3,6} — jump would land at {4,5}... wait,
      # that's on the board. Let's use dark at {5,6} with light at {6,7} → {7,8}
      #
      #     0   1   2   3   4   5   6   7
      # 5 | . |   | . |   | . |   | d |   |
      # 6 |   | . |   | . |   | . |   | l |
      board =
        %Board{}
        |> Board.put_piece({5, 6}, :dark)
        |> Board.put_piece({6, 7}, :light)

      assert {:error, :invalid_move} = Rules.validate_move(board, :dark, {5, 6}, {7, 8})
    end
  end

  describe "legal_moves/3" do
    test "returns both diagonal moves for a checker in the open" do
      # Dark checker at {3,2} with no pieces around — two forward diagonals
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | d |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({3, 2}, :dark)

      moves = Rules.legal_moves(board, :dark, {3, 2})

      assert Enum.sort(moves) == [{4, 1}, {4, 3}]
    end

    test "returns jump destinations when jumps are available" do
      # Dark at {2,1} with light at {3,2} — can jump to {4,3}
      # Also has a simple move to {3,0} (but jumps are mandatory,
      # so legal_moves should return only jumps when available)
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)

      moves = Rules.legal_moves(board, :dark, {2, 1})

      assert moves == [{4, 3}]
    end

    test "returns all four directions for a king in the open" do
      # Dark king at {4,3} with nothing around
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | D |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({4, 3}, :dark_king)

      moves = Rules.legal_moves(board, :dark, {4, 3})

      assert Enum.sort(moves) == [{3, 2}, {3, 4}, {5, 2}, {5, 4}]
    end

    test "returns empty list when a piece is blocked" do
      # Dark at {2,1} blocked by own pieces at {3,0} and {3,2}
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | d |   | d |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 0}, :dark)
        |> Board.put_piece({3, 2}, :dark)

      assert Rules.legal_moves(board, :dark, {2, 1}) == []
    end

    test "excludes simple moves when any piece of that color can jump" do
      # Dark at {2,1} can simple-move to {3,0}. Dark at {2,5} can jump
      # over light at {3,6} to {4,7}. Since any dark piece can jump,
      # {2,1}'s simple moves are excluded (mandatory capture).
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | d |   | . |
      # 3 | . |   | . |   | . |   | l |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({2, 5}, :dark)
        |> Board.put_piece({3, 6}, :light)

      # {2,1} has no jumps itself, but another dark piece does,
      # so {2,1}'s simple moves are excluded
      assert Rules.legal_moves(board, :dark, {2, 1}) == []
    end

    test "respects board edges" do
      # Dark at {2,7} — can only move to {3,6} (right side is off the board)
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | d |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({2, 7}, :dark)

      assert Rules.legal_moves(board, :dark, {2, 7}) == [{3, 6}]
    end
  end

  describe "movable_pieces/2" do
    test "returns all pieces that can move for the given color" do
      # Dark at {2,1} and {2,3} — both can move forward
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | d |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({2, 3}, :dark)

      pieces = Rules.movable_pieces(board, :dark)

      assert Enum.sort(pieces) == [{2, 1}, {2, 3}]
    end

    test "only returns pieces that can jump when jumps are available" do
      # Dark at {2,1} can simple-move only. Dark at {2,5} can jump
      # light at {3,6}. Mandatory capture means only {2,5} is movable.
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | d |   | . |
      # 3 | . |   | . |   | . |   | l |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({2, 5}, :dark)
        |> Board.put_piece({3, 6}, :light)

      assert Rules.movable_pieces(board, :dark) == [{2, 5}]
    end

    test "returns empty list when no pieces can move" do
      # Dark at {7,0} — no forward moves (row 7 is the edge)
      # and no jumps available
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | d |   | . |   | . |   | . |   |
      board = %Board{} |> Board.put_piece({7, 0}, :dark)

      assert Rules.movable_pieces(board, :dark) == []
    end

    test "does not include opponent pieces" do
      # Dark at {3,2} can move. Light at {5,4} can move.
      # Asking for dark should only return dark pieces.
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | d |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | l |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({3, 2}, :dark)
        |> Board.put_piece({5, 4}, :light)

      assert Rules.movable_pieces(board, :dark) == [{3, 2}]
      assert Rules.movable_pieces(board, :light) == [{5, 4}]
    end
  end
end
