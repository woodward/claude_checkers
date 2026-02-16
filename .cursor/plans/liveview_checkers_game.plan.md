---
name: LiveView Checkers Game
overview: Build a LiveView page at `/game` where two players in different browsers can play checkers against each other in real time, using a GenServer for game state and PubSub for synchronization.
todos:
  - id: board-to-list
    content: Add Board.to_list/1 with tests (returns all 64 squares for grid rendering)
    status: completed
  - id: game-server
    content: Build GameServer GenServer with tests (join, get_state, move, reset, PubSub broadcast)
    status: completed
  - id: supervision
    content: Add GameServer to application.ex supervision tree
    status: completed
  - id: router
    content: Add live /game route and session token plug
    status: completed
  - id: game-live-basic
    content: "GameLive: mount, subscribe to PubSub, render the board grid"
    status: completed
  - id: game-live-interaction
    content: "GameLive: piece selection, legal move highlighting, move execution"
    status: completed
  - id: game-live-status
    content: "GameLive: turn indicator, waiting for opponent, game over display"
    status: completed
  - id: game-live-tests
    content: PhoenixTest tests for GameLive
    status: pending
isProject: false
---

# LiveView Checkers Game

## Architecture

```mermaid
graph TD
    Browser1[Browser 1 - Dark] -->|WebSocket| LV1[GameLive]
    Browser2[Browser 2 - Light] -->|WebSocket| LV2[GameLive]
    LV1 -->|call/cast| GS[GameServer GenServer]
    LV2 -->|call/cast| GS
    GS -->|broadcast| PS[Phoenix.PubSub]
    PS -->|game_updated| LV1
    PS -->|game_updated| LV2
    GS -->|delegates to| GE[Game Engine]
```



- **Single game URL**: `/game` — no multi-game support yet
- **Player assignment**: First to connect is dark, second is light. A random token stored in the LiveView session identifies each player across reconnects.
- **State management**: A single named `Checkers.GameServer` GenServer holds the `Game` struct. Supervised under a standard child in `application.ex`.
- **Real-time sync**: `Phoenix.PubSub` (already configured as `Checkers.PubSub`) broadcasts state changes to both connected LiveViews.

## Key Files to Create/Modify

### New files

- `lib/checkers/game_server.ex` — GenServer wrapping `Checkers.Game`, tracks player tokens, broadcasts via PubSub
- `lib/checkers_web/live/game_live.ex` — LiveView: renders board, handles click interactions, subscribes to PubSub
- `test/checkers_web/live/game_live_test.exs` — PhoenixTest-driven tests
- `test/checkers/game_server_test.exs` — Unit tests for the GenServer

### Modified files

- `lib/checkers/application.ex` — Add `GameServer` to supervision tree
- `lib/checkers_web/router.ex` — Add `live "/game", GameLive` route
- `lib/checkers/board.ex` — Add `Board.to_list/1` helper for rendering the 8x8 grid

## Implementation Plan (TDD)

### Phase 1: GameServer GenServer

- `GameServer.start_link/1` — starts with a fresh game
- `GameServer.get_state/0` — returns the current game + player assignments
- `GameServer.join/1` — accepts a player token, assigns dark (first) or light (second), returns color
- `GameServer.move/3` — accepts player_token, from, to; validates it's that player's turn; delegates to `Game.move/3`; broadcasts update via PubSub
- `GameServer.reset/0` — resets to a new game (handy for dev/testing)
- Broadcasts `{:game_updated, game_state}` on topic `"game"` after each successful move

### Phase 2: Board.to_list/1

- Returns all 64 squares as `[{position, piece_or_nil}, ...]` sorted by row then col, for easy grid rendering in the template

### Phase 3: GameLive LiveView

- On mount: generate/retrieve player token from session, call `GameServer.join/1`, subscribe to PubSub topic `"game"`
- Assigns: `game`, `player_color`, `selected_piece`, `legal_moves`
- **Board rendering**: 8x8 grid using Tailwind CSS. Dark squares are clickable. Pieces shown as circles (dark brown / cream). Kings get a crown indicator.
- **Interaction flow**:
  1. Click a piece (if it's your turn and the piece is movable) -> highlights it, shows legal move destinations
  2. Click a legal destination -> sends move to GameServer -> board updates via PubSub
  3. Click elsewhere -> deselects
- **Status display**: Whose turn it is, game result, "waiting for opponent" if only one player

### Phase 4: Router + Supervision

- Add `GameServer` as a child in `application.ex`
- Add `live "/game", GameLive` in the router (inside existing browser scope)
- Wire up session-based player token via `on_mount` or `mount` params

### Phase 5: PhoenixTest Tests

- Test board renders correctly
- Test clicking a piece highlights legal moves
- Test making a move updates the board
- Test turn enforcement (can't move opponent's pieces)
- Test two-player flow (two LiveView sessions playing against each other)

