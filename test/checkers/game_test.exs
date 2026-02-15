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

  describe "multi-jump" do
    test "turn does not switch when another jump is available" do
      # Dark at {2,1} will double-jump over light at {3,2} and {5,4}
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | l |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)
        |> Board.put_piece({5, 4}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      # First jump: {2,1} -> {4,3}, captures light at {3,2}
      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})

      # Turn stays with dark because another jump is available from {4,3}
      assert game.turn == :dark
      assert game.must_jump_from == {4, 3}

      # First capture removed
      assert Board.piece_at(game.board, {3, 2}) == nil
    end

    test "turn switches after completing a multi-jump chain" do
      # Same setup as above — complete both jumps
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | l |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)
        |> Board.put_piece({5, 4}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      # First jump
      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})
      # Second jump: {4,3} -> {6,5}, captures light at {5,4}
      assert {:ok, game} = Game.move(game, {4, 3}, {6, 5})

      # Now turn switches to light — no more jumps available
      assert game.turn == :light
      assert game.must_jump_from == nil

      # Both captures removed, piece at final landing
      assert Board.piece_at(game.board, {6, 5}) == :dark
      assert Board.piece_at(game.board, {3, 2}) == nil
      assert Board.piece_at(game.board, {5, 4}) == nil
      assert Board.piece_at(game.board, {2, 1}) == nil
    end

    test "during multi-jump, only the jumping piece can move" do
      # After first jump, trying to move a different piece should fail
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | d |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | l |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({2, 3}, :dark)
        |> Board.put_piece({3, 2}, :light)
        |> Board.put_piece({5, 4}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      # First jump with {2,1}
      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})
      assert game.must_jump_from == {4, 3}

      # Try to move the other dark piece at {2,3} — should be rejected
      assert {:error, :must_continue_jump} = Game.move(game, {2, 3}, {3, 4})
    end

    test "during multi-jump, the jumping piece must jump (not simple move)" do
      # After first jump, the piece at {4,3} must jump, not make a simple move
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | l |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)
        |> Board.put_piece({5, 4}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      # First jump
      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})
      assert game.must_jump_from == {4, 3}

      # Try a simple move with the jumping piece — should be rejected
      assert {:error, :must_continue_jump} = Game.move(game, {4, 3}, {5, 2})
    end

    test "single jump with no further jumps switches turn normally" do
      # Only one jump available — turn switches after it
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

      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})

      assert game.turn == :light
      assert game.must_jump_from == nil
    end
  end

  describe "mandatory capture" do
    test "rejects a simple move when a jump is available" do
      # Dark at {2,1} could jump over light at {3,2}, but tries a simple move instead
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | d |   | l |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({3, 0}, :dark)
        |> Board.put_piece({3, 2}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      # Try a simple move with the other dark piece — should be rejected
      assert {:error, :jump_available} = Game.move(game, {3, 0}, {4, 1})
    end

    test "rejects a simple move even when the moving piece has no jump" do
      # Dark at {4,1} has no jump, but dark at {2,1} does — still must jump
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | d |   | . |   | . |   | . |
      # 3 | . |   | l |   | . |   | . |   |
      # 4 |   | d |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 1}, :dark)
        |> Board.put_piece({4, 1}, :dark)
        |> Board.put_piece({3, 2}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      # {2,1} has a jump available, so no simple moves are allowed for any piece
      assert {:error, :jump_available} = Game.move(game, {4, 1}, {5, 2})
    end

    test "allows a jump when a jump is available" do
      # Dark at {2,1} must jump over light at {3,2} — this should succeed
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

      assert {:ok, game} = Game.move(game, {2, 1}, {4, 3})

      assert Board.piece_at(game.board, {4, 3}) == :dark
      assert Board.piece_at(game.board, {3, 2}) == nil
    end

    test "allows a simple move when no jump is available" do
      # No jumps available for dark — simple move should work
      #
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

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      assert {:ok, _game} = Game.move(game, {2, 1}, {3, 2})
    end
  end

  describe "win conditions" do
    test "dark wins by capturing the last light piece" do
      # Dark at {5,4} jumps light at {6,5}, landing at {7,6} — no light pieces remain
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | d |   | . |   |
      # 6 |   | . |   | . |   | l |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({5, 4}, :dark)
        |> Board.put_piece({6, 5}, :light)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      assert {:ok, game} = Game.move(game, {5, 4}, {7, 6})

      assert game.status == :dark_wins
      assert Board.piece_at(game.board, {6, 5}) == nil
    end

    test "light wins by capturing the last dark piece" do
      # Light at {2,3} jumps dark at {1,2}, landing at {0,1} — no dark pieces remain
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | . |   | . |   | . |   | . |
      # 1 | . |   | d |   | . |   | . |   |
      # 2 |   | . |   | l |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | . |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      board =
        %Board{}
        |> Board.put_piece({2, 3}, :light)
        |> Board.put_piece({1, 2}, :dark)

      game = %Game{board: board, turn: :light, status: :playing, moves: []}

      assert {:ok, game} = Game.move(game, {2, 3}, {0, 1})

      assert game.status == :light_wins
      assert Board.piece_at(game.board, {1, 2}) == nil
    end

    test "dark wins when light has pieces but no legal moves" do
      # Light at {1,0} is blocked: only forward diagonal is {0,1} which is
      # occupied by dark, and a jump would land at {-1,2} (off board).
      #
      #     0   1   2   3   4   5   6   7
      # 0 |   | d |   | . |   | . |   | . |
      # 1 | l |   | . |   | . |   | . |   |
      # 2 |   | . |   | . |   | . |   | . |
      # 3 | . |   | . |   | . |   | . |   |
      # 4 |   | . |   | . |   | . |   | . |
      # 5 | . |   | . |   | . |   | . |   |
      # 6 |   | d |   | . |   | . |   | . |
      # 7 | . |   | . |   | . |   | . |   |
      #
      # Dark at {6,1} makes a simple move to {7,2}; light has no legal moves → dark wins.
      board =
        %Board{}
        |> Board.put_piece({1, 0}, :light)
        |> Board.put_piece({0, 1}, :dark)
        |> Board.put_piece({6, 1}, :dark)

      game = %Game{board: board, turn: :dark, status: :playing, moves: []}

      assert {:ok, game} = Game.move(game, {6, 1}, {7, 2})

      assert game.status == :dark_wins
    end

    test "rejects moves when the game is already over" do
      # Game is already won — no more moves allowed
      board =
        %Board{}
        |> Board.put_piece({3, 2}, :dark)

      game = %Game{board: board, turn: :dark, status: :dark_wins, moves: []}

      assert {:error, :game_over} = Game.move(game, {3, 2}, {4, 3})
    end
  end
end
