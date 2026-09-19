# Stain

A small SwiftUI puzzle game about mixing paint. Walk a grid, pick up pigment from source cells, and deposit it onto target cells until every target matches its required color exactly.

## Gameplay

- The board is a grid of cells. Tap a cell adjacent to your current position to move onto it.
- **Source cells** (marked with an ink-stain dot) load whatever pigment they represent into your hand — the color you're currently "holding" is shown as a swatch at the bottom of the screen.
- **Target cells** (outlined in a color) need to be filled with an exact combination of pigments to be satisfied.
- Stepping onto an empty cell while holding a pigment deposits it there. Pigments mix:

  | Combination | Result |
  |---|---|
  | Red + Yellow | Orange |
  | Yellow + Blue | Green |
  | Red + Blue | Purple |
  | Red + Yellow + Blue | Black (impassable wall) |

- A **non-target** cell that mixes all three pigments turns into a black wall and can no longer be entered.
- A **target** cell that overflows to all three pigments instead of matching its required color ends the run in failure.
- You win a level once every target cell's pigments exactly match its required color.
- **Undo** rewinds one move; **重設** restarts the level from scratch.

## Levels

Levels are defined as ASCII-art rows (`R`/`Y`/`B` = pigment source, lowercase/`o`/`g`/`p` = target combinations, `.` = empty) with a `par` move count used for the crown rating.

- **教學 (Tutorial):** 移動 → 沾色 → 汙染 — introduces movement, single-color deposits, then mixing and walls.
- **正式關卡 (Formal):** 交織 → 包圍 → 偽軟 — larger 4×4 boards with all three pigments in play.

The app opens directly into the tutorial level-select screen on first launch, and automatically defaults to the formal level-select screen once all tutorial levels have been completed at least once. Each section's select screen has a cross-link button to jump to the other section without starting a level.

## Progress & scoring

- Finishing a level records your best (lowest) move count to `UserDefaults`, keyed per level.
- Level-select cards show your best step count and a two-crown rating: both crowns turn gold if you finished at or under par, otherwise one.
- Winning a level shows a full-screen result overlay (dimmed background, final board preview, step count, crown rating) with **重新遊玩 / 下一關 / 選關** as the only way out.

## Settings

Reachable via the gear icon on the level-select and gameplay screens:

- **背景音樂** — toggles looped background music (`Watercolor_Drift.mp3`, played via `AVAudioPlayer` off the main thread) with a volume slider that disables when music is off.
- **震動** — toggles a light haptic tap on every valid move.

An info (`i`) button on the gameplay screen opens a quick reference for the mixing rules.

## Tech notes

- SwiftUI, targeting iOS 27 (Xcode's `PBXFileSystemSynchronizedRootGroup` project format — files dropped into `pigment/pigment/` are picked up automatically, no manual project registration needed).
- Custom app icon built with Icon Composer (`AppIcon.icon`), rendering default/dark/clear/tinted appearances automatically from a single layered source.
- Numbers and English UI text (step counts, "Undo") use a bundled brush-script font (`NanumBrushScript-Regular.ttf`, Nanum Brush Script, OFL-licensed); Chinese text stays on the system font since the font has no CJK glyphs.
- No backend — all state is local (`UserDefaults` for progress/settings).

## Project structure

```
pigment/
  pigment/
    ContentView.swift      # All game logic and views live here
    pigmentApp.swift        # App entry point
    AppIcon.icon/            # Icon Composer app icon
    Fonts/                   # Bundled brush font + OFL license
    Sounds/                  # Background music
    Assets.xcassets/         # Accent color, ink-stain image
  pigment.xcodeproj/
```
