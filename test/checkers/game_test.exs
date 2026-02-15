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

  # Standard starting position used by Game.new/0:
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

  describe "move/3" do
    test "dark can make a simple diagonal move forward" do
      # Move dark {2,1} -> {3,2}
      #
      # Before:                          After:
      #     0   1   2   3                    0   1   2   3
      # 2 |   | d |   | d |             2 |   | . |   | d |
      # 3 | . |   | . |   |             3 | . |   | d |   |
      game = Game.new()
      assert Board.piece_at(game.board, {2, 1}) == :dark
      assert Board.piece_at(game.board, {3, 2}) == nil

      assert {:ok, game} = Game.move(game, {2, 1}, {3, 2})

      assert Board.piece_at(game.board, {2, 1}) == nil
      assert Board.piece_at(game.board, {3, 2}) == :dark
    end

    test "turn switches to light after dark moves" do
      # Move dark {2,1} -> {3,2}; turn should flip to :light
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
      # It's dark's turn; trying to move light piece at {5,0}
      game = Game.new()

      assert {:error, :not_your_piece} = Game.move(game, {5, 0}, {4, 1})
    end

    test "rejects moving to a non-diagonal square" do
      # {2,1} -> {3,1} is straight down, not diagonal
      game = Game.new()

      assert {:error, :invalid_move} = Game.move(game, {2, 1}, {3, 1})
    end

    test "rejects moving to an occupied square" do
      # {2,1} -> {1,2} is backward and {1,2} has a dark piece
      game = Game.new()
      assert Board.piece_at(game.board, {1, 2}) != nil

      assert {:error, :destination_occupied} = Game.move(game, {2, 1}, {1, 2})
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

  describe "king promotion" do
    test "dark checker is promoted to king upon reaching row 7" do
      # Dark checker at {6,5} moves to {7,6} (back row)
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | d |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({6, 5}, :dark)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      assert {:ok, game} = Game.move(game, {6, 5}, {7, 6})

      assert Board.piece_at(game.board, {7, 6}) == :dark_king
    end

    test "light checker is promoted to king upon reaching row 0" do
      # Light checker at {1,2} moves to {0,1} (back row)
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | l |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({1, 2}, :light)

      game = %Game{board: board, turn: :light, status: :playing, moves: []}

      assert {:ok, game} = Game.move(game, {1, 2}, {0, 1})

      assert Board.piece_at(game.board, {0, 1}) == :light_king
    end

    test "a king is not re-promoted when it reaches the back row" do
      # Dark king at {6,3} moves to {7,4} — should stay :dark_king
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | D |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({6, 3}, :dark_king)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      assert {:ok, game} = Game.move(game, {6, 3}, {7, 4})

      assert Board.piece_at(game.board, {7, 4}) == :dark_king
    end
  end
end
