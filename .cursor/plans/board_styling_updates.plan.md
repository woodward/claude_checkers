---
name: Board styling updates
overview: Update the board colors to a classic wood feel (walnut/maple), change pieces to red vs black, and increase the size of status/turn labels.
todos:
  - id: update-labels
    content: Increase size of status badges and turn indicator labels in game_live.html.heex
    status: completed
  - id: update-board-colors
    content: Change board square colors to walnut brown / light maple in game_live.ex square_classes/6
    status: completed
  - id: update-piece-colors
    content: Change piece colors to black vs red in game_live.ex piece_classes/3
    status: completed
  - id: update-board-border
    content: Change board border color to match wood theme in game_live.html.heex
    status: completed
  - id: test-and-commit
    content: Run mix test, mix dialyzer, and commit
    status: completed
isProject: false
---

# Board Styling Updates

## Changes in [game_live.html.heex](lib/checkers_web/live/game_live.html.heex)

### Larger labels

- **Title** (line 3): Already `text-2xl` -- consider removing since "Checkers" is in the header (user previously noted it was redundant)
- **Status badges** (lines 8-24): Change from `badge` (small) to `badge-lg` and bump text with `text-lg font-semibold`
- **Turn indicators** (lines 59-71): Change from `badge` to `badge-lg` with `text-lg`

## Changes in [game_live.ex](lib/checkers_web/live/game_live.ex)

### Board colors -- classic wood (1A)

- **Dark squares** (line 125): `bg-emerald-800` -> `bg-amber-900` (warm walnut brown)
- **Light squares** (line 125): `bg-amber-50` -> `bg-amber-200` (light maple)
- **Board border** (line 29 of heex): `border-emerald-950` -> `border-amber-950` (dark wood border)

### Piece colors -- red vs black (2B)

- **Dark pieces** (line 142): `bg-red-800 border-red-950 text-red-200 shadow-red-900/40` -> `bg-gray-900 border-gray-950 text-gray-300 shadow-gray-900/50` (black)
- **Light pieces** (line 143): `bg-amber-100 border-amber-300 text-amber-800 shadow-amber-200/40` -> `bg-red-700 border-red-900 text-red-100 shadow-red-800/50` (red)

Note: In checkers, "dark" player traditionally uses black pieces and "light" player uses red. This maps naturally to the existing color assignments.