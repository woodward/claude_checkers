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
end
