defmodule Checkers.GameTest do
  use ExUnit.Case, async: true

  alias Checkers.{Game, Board}

  describe "new/0" do
    test "returns a Game struct" do
      game = Game.new()

      assert %Game{} = game
    end

    test "starts with a fresh board" do
      game = Game.new()

      assert %Board{} = game.board
      assert map_size(game.board.pieces) == 24
    end

    test "dark moves first" do
      game = Game.new()

      assert game.turn == :dark
    end

    test "starts in the playing state" do
      game = Game.new()

      assert game.status == :playing
    end

    test "starts with an empty move history" do
      game = Game.new()

      assert game.moves == []
    end
  end

  describe "move/3" do
    test "dark can make a simple diagonal move forward" do
      game = Game.new()
      assert Board.piece_at(game.board, {2, 1}) == :dark
      assert Board.piece_at(game.board, {3, 2}) == nil

      assert {:ok, game} = Game.move(game, {2, 1}, {3, 2})

      assert Board.piece_at(game.board, {2, 1}) == nil
      assert Board.piece_at(game.board, {3, 2}) == :dark
    end

    test "turn switches to light after dark moves" do
      game = Game.new()
      assert game.turn == :dark

      assert {:ok, game} = Game.move(game, {2, 1}, {3, 2})

      assert game.turn == :light
    end

    test "move is recorded in history" do
      game = Game.new()

      assert {:ok, game} = Game.move(game, {2, 1}, {3, 2})

      assert game.moves == [{{2, 1}, {3, 2}}]
    end

    test "rejects moving the wrong color's piece" do
      game = Game.new()

      assert {:error, _reason} = Game.move(game, {5, 0}, {4, 1})
    end

    test "rejects moving to a non-diagonal square" do
      game = Game.new()

      assert {:error, _reason} = Game.move(game, {2, 1}, {3, 1})
    end

    test "rejects moving to an occupied square" do
      game = Game.new()
      assert Board.piece_at(game.board, {1, 2}) != nil

      assert {:error, _reason} = Game.move(game, {2, 1}, {1, 2})
    end

    test "a jump removes the captured piece" do
      # Custom board: dark at {2,1}, light at {3,2}, landing {4,3} empty
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

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      assert Board.piece_at(game.board, {2, 1}) == :dark
      assert Board.piece_at(game.board, {3, 2}) == :light
      assert Board.piece_at(game.board, {4, 3}) == nil

      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})

      # Piece moved to landing square
      assert Board.piece_at(game.board, {4, 3}) == :dark
      # Source is now empty
      assert Board.piece_at(game.board, {2, 1}) == nil
      # Captured piece is removed
      assert Board.piece_at(game.board, {3, 2}) == nil
    end
  end
end
