defmodule Checkers.GameServerTest do
  use ExUnit.Case, async: false

  alias Checkers.GameServer

  setup do
    # Start a fresh GameServer for each test
    name = :"test_server_#{System.unique_integer()}"
    server = start_supervised!({GameServer, name: name})
    %{server: server, name: name}
  end

  describe "join/2" do
    test "first player gets :dark", %{server: server} do
      assert {:ok, :dark} = GameServer.join(server, "player-1")
    end

    test "second player gets :light", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")

      assert {:ok, :light} = GameServer.join(server, "player-2")
    end

    test "same token rejoining gets the same color", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")

      assert {:ok, :dark} = GameServer.join(server, "player-1")
    end

    test "third player gets :spectator", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")

      assert {:ok, :spectator} = GameServer.join(server, "player-3")
    end
  end

  describe "get_state/1" do
    test "returns the game and player info", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")

      state = GameServer.get_state(server)

      assert %{game: %Checkers.Game{}, players: players} = state
      assert players.dark == "player-1"
      assert players.light == nil
    end
  end

  describe "move/4" do
    test "dark player can make a move on dark's turn", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")

      # Dark moves from {2,1} to {3,0} (standard opening)
      assert {:ok, _game} = GameServer.move(server, "player-1", {2, 1}, {3, 0})
    end

    test "light player cannot move on dark's turn", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")

      assert {:error, :not_your_turn} = GameServer.move(server, "player-2", {5, 0}, {4, 1})
    end

    test "spectator cannot move", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")
      {:ok, :spectator} = GameServer.join(server, "spectator")

      assert {:error, :not_your_turn} = GameServer.move(server, "spectator", {2, 1}, {3, 0})
    end

    test "unknown token cannot move", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")

      assert {:error, :not_your_turn} = GameServer.move(server, "unknown", {2, 1}, {3, 0})
    end

    test "broadcasts game_updated after a successful move", %{server: server, name: name} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")

      Phoenix.PubSub.subscribe(Checkers.PubSub, GameServer.topic(name))

      {:ok, _game} = GameServer.move(server, "player-1", {2, 1}, {3, 0})

      assert_receive {:game_updated, %{game: %Checkers.Game{turn: :light}}}
    end

    test "does not broadcast on a failed move", %{server: server, name: name} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")

      Phoenix.PubSub.subscribe(Checkers.PubSub, GameServer.topic(name))

      # Invalid move
      {:error, _} = GameServer.move(server, "player-1", {2, 1}, {5, 0})

      refute_receive {:game_updated, _}
    end
  end

  describe "reset/1" do
    test "resets to a fresh game and clears players", %{server: server} do
      {:ok, :dark} = GameServer.join(server, "player-1")
      {:ok, :light} = GameServer.join(server, "player-2")
      {:ok, _game} = GameServer.move(server, "player-1", {2, 1}, {3, 0})

      :ok = GameServer.reset(server)

      state = GameServer.get_state(server)
      assert state.game.turn == :dark
      assert state.game.moves == []
      assert state.players.dark == nil
      assert state.players.light == nil
    end
  end

  describe "topic/1" do
    test "returns the PubSub topic for a server name", %{name: name} do
      assert GameServer.topic(name) == "game:#{inspect(name)}"
    end
  end
end
