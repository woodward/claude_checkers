# Checkers

A real-time multiplayer American Checkers game built with Elixir, Phoenix, and LiveView. Developed via pair programming with Claude Opus 4.6 (Anthropic) in Cursor.

## Features

- **American Checkers rules**: 8x8 board, 12 pieces per side, mandatory captures, multi-jump chains, king promotion
- **Real-time multiplayer**: Two players connect via browser — first player is dark, second is light
- **Live updates**: Moves broadcast instantly to both players via Phoenix PubSub
- **Spectator mode**: Additional visitors can watch the game in progress
- **Interactive UI**: Click-to-select, legal move highlighting, turn indicators

## Architecture

The game logic is split into focused modules:

- `Checkers.Board` — board state, piece placement, and queries
- `Checkers.Rules` — move validation, legal move computation, mandatory capture enforcement
- `Checkers.Game` — game state machine (turns, status, move history, promotion, win detection)
- `Checkers.GameServer` — GenServer wrapping a game with player assignment and PubSub broadcasts
- `CheckersWeb.GameLive` — LiveView UI for the board, interaction, and real-time sync

## Getting Started

```bash
mix setup
mix phx.server
```

Visit [localhost:4000/game](http://localhost:4000/game) to play. Open a second browser window (or incognito) to join as the opponent.

## Tests

```bash
mix test          # 102 tests
mix dialyzer      # typespec validation
```
