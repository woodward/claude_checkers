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
end
