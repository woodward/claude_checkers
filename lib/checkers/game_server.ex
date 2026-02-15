defmodule Checkers.GameServer do
  @moduledoc """
  A GenServer that wraps a `Checkers.Game`, manages player assignments,
  and broadcasts state changes via PubSub.
  """

  use GenServer

  alias Checkers.Game

  @type players :: %{dark: String.t() | nil, light: String.t() | nil}

  # --- Client API ---

  @doc """
  Starts a GameServer. Accepts an optional `:name` option.
  """
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @doc """
  Joins the game with a player token. Returns `{:ok, color}` where
  color is `:dark`, `:light`, or `:spectator`.

  The first token to join gets `:dark`, the second gets `:light`.
  Re-joining with the same token returns the previously assigned color.
  """
  @spec join(GenServer.server(), String.t()) :: {:ok, :dark | :light | :spectator}
  def join(server, player_token) do
    GenServer.call(server, {:join, player_token})
  end

  @doc """
  Returns the current game state and player assignments.
  """
  @spec get_state(GenServer.server()) :: %{game: Game.t(), players: players()}
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Attempts a move. Validates the player token matches the current turn.
  Returns `{:ok, game}` or `{:error, reason}`.
  """
  @spec move(GenServer.server(), String.t(), Checkers.Board.position(), Checkers.Board.position()) ::
          {:ok, Game.t()} | {:error, atom()}
  def move(server, player_token, from, to) do
    GenServer.call(server, {:move, player_token, from, to})
  end

  @doc """
  Resets the game to a fresh state, clearing player assignments.
  """
  @spec reset(GenServer.server()) :: :ok
  def reset(server) do
    GenServer.call(server, :reset)
  end

  @doc """
  Returns the PubSub topic for the given server.
  """
  @spec topic(GenServer.server()) :: String.t()
  def topic(server) do
    "game:#{inspect(server)}"
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, initial_state()}
  end

  @impl true
  def handle_call({:join, token}, _from, state) do
    {color, new_state} = assign_player(token, state)
    {:reply, {:ok, color}, new_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, %{game: state.game, players: state.players}, state}
  end

  def handle_call({:move, token, from, to}, _from, state) do
    if token_matches_turn?(token, state) do
      case Game.move(state.game, from, to) do
        {:ok, new_game} ->
          new_state = %{state | game: new_game}
          broadcast(new_state)
          {:reply, {:ok, new_game}, new_state}

        {:error, _reason} = error ->
          {:reply, error, state}
      end
    else
      {:reply, {:error, :not_your_turn}, state}
    end
  end

  def handle_call(:reset, _from, _state) do
    new_state = initial_state()
    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  # --- Private Helpers ---

  defp initial_state do
    %{
      game: Game.new(),
      players: %{dark: nil, light: nil}
    }
  end

  defp assign_player(token, %{players: players} = state) do
    cond do
      players.dark == token -> {:dark, state}
      players.light == token -> {:light, state}
      players.dark == nil -> {:dark, put_in(state, [:players, :dark], token)}
      players.light == nil -> {:light, put_in(state, [:players, :light], token)}
      true -> {:spectator, state}
    end
  end

  defp token_matches_turn?(token, %{game: game, players: players}) do
    case game.turn do
      :dark -> players.dark == token
      :light -> players.light == token
    end
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      Checkers.PubSub,
      topic(self()),
      {:game_updated, %{game: state.game, players: state.players}}
    )
  end
end
