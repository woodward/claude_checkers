defmodule CheckersWeb.GameLive do
  use CheckersWeb, :live_view

  alias Checkers.{Board, Game, GameServer, Rules}

  @server Checkers.GameServer

  @impl Phoenix.LiveView
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, session, socket) do
    player_token = session["player_token"]
    {:ok, player_color} = GameServer.join(@server, player_token)
    state = GameServer.get_state(@server)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Checkers.PubSub, GameServer.topic(@server))
    end

    {:ok,
     socket
     |> assign(:player_token, player_token)
     |> assign(:player_color, player_color)
     |> assign(:selected, nil)
     |> assign(:legal_moves, [])
     |> assign_game_state(state)}
  end

  @impl Phoenix.LiveView
  @spec handle_info({:game_updated, map()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:game_updated, state}, socket) do
    {:noreply,
     socket
     |> assign(:selected, nil)
     |> assign(:legal_moves, [])
     |> assign_game_state(state)}
  end

  @impl Phoenix.LiveView
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("square_clicked", %{"row" => row_str, "col" => col_str}, socket) do
    pos = {String.to_integer(row_str), String.to_integer(col_str)}

    socket = handle_click(pos, socket)
    {:noreply, socket}
  end

  # --- Private Helpers ---

  @spec handle_click(Board.position(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp handle_click(pos, socket) do
    %{
      selected: selected,
      legal_moves: legal_moves,
      player_color: player_color,
      player_token: player_token,
      game: game
    } = socket.assigns

    cond do
      # Not this player's turn or not a player
      player_color not in [:dark, :light] or game.turn != player_color ->
        socket

      # Clicked a legal move destination — make the move
      selected != nil and pos in legal_moves ->
        case GameServer.move(@server, player_token, selected, pos) do
          {:ok, _game} ->
            # PubSub broadcast will update state
            socket

          {:error, _reason} ->
            assign(socket, selected: nil, legal_moves: [])
        end

      # Clicked a piece of the current player's color — select it
      piece_belongs_to_player?(game.board, pos, player_color) ->
        moves = Rules.legal_moves(game.board, player_color, pos)

        if moves == [] do
          assign(socket, selected: nil, legal_moves: [])
        else
          assign(socket, selected: pos, legal_moves: moves)
        end

      # Clicked elsewhere — deselect
      true ->
        assign(socket, selected: nil, legal_moves: [])
    end
  end

  @spec piece_belongs_to_player?(Board.t(), Board.position(), Board.color()) :: boolean()
  defp piece_belongs_to_player?(board, pos, color) do
    piece = Board.piece_at(board, pos)
    piece != nil and Board.color(piece) == color
  end

  @spec assign_game_state(Phoenix.LiveView.Socket.t(), %{game: Game.t(), players: GameServer.players()}) ::
          Phoenix.LiveView.Socket.t()
  defp assign_game_state(socket, %{game: game, players: players}) do
    socket
    |> assign(:game, game)
    |> assign(:players, players)
    |> assign(:squares, Board.to_list(game.board))
  end

  @spec square_classes(
          Board.position(),
          Board.piece() | nil,
          Board.position() | nil,
          [Board.position()],
          Board.color() | :spectator,
          Board.color()
        ) :: list()
  defp square_classes(pos, piece, selected, legal_moves, player_color, turn) do
    {row, col} = pos
    dark_square? = rem(row + col, 2) == 1
    selected? = pos == selected
    legal_target? = pos in legal_moves
    clickable? = player_color in [:dark, :light] and turn == player_color

    [
      "flex items-center justify-center aspect-square",
      if(dark_square?, do: "bg-amber-800", else: "bg-amber-100"),
      selected? && "ring-4 ring-inset ring-primary",
      legal_target? && "ring-4 ring-inset ring-success",
      clickable? && dark_square? && piece != nil && "cursor-pointer",
      clickable? && legal_target? && "cursor-pointer"
    ]
  end

  @spec piece_classes(Board.piece(), Board.position(), Board.position() | nil) :: list()
  defp piece_classes(piece, pos, selected) do
    color = Board.color(piece)
    selected? = pos == selected

    [
      "rounded-full w-3/4 h-3/4 flex items-center justify-center",
      "border-2 shadow-md transition-transform",
      if(color == :dark,
        do: "bg-stone-800 border-stone-900 text-amber-200",
        else: "bg-amber-50 border-amber-200 text-stone-800"
      ),
      selected? && "scale-110 ring-2 ring-primary"
    ]
  end

  @spec king?(Board.piece()) :: boolean()
  defp king?(piece), do: piece in [:dark_king, :light_king]

  @spec status_text(Game.status()) :: String.t()
  defp status_text(:dark_wins), do: "Dark wins!"
  defp status_text(:light_wins), do: "Light wins!"
  defp status_text(:draw), do: "Draw!"
  defp status_text(_), do: ""
end
