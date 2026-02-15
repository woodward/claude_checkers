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
end
