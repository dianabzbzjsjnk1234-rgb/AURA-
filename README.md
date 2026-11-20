# AURA

AURA is a relaxing light-reflection puzzle: place and turn mirrors on a grid to bend the light beam.

**Version 4.5** (Assignment 4) вЂ” Android APK and iOS build, 8 chapters.

## Team

- **Elmira** вЂ” mechanics & levels (beam reflection, undo, star rewards; level data `level_1/2.json`; demo: Chapter 1 в†’ Chapter 2)
- **Khalida** вЂ” interface & game flow (bigger buttons, contrast, pause; iPhone layout, settings, saving; demo: pause, restart, rotation)
- **Diana** вЂ” visuals, animation & sound (editor animation, particles; sounds, music, Reduce animation; demo: animations, sound on silent)

## Requirements and opening

For running the project, Godot 4.7.2 (stable) is needed. Download the repository (Code в†’ Download ZIP on GitHub, or git clone) and extract it. Open Godot, click Import and select the `GameProject/project.godot` file. Once the project opens, press F5 to run the game.

Auto-tests are located in the `tests/` folder. To run them, open `res://tests/verify.tscn` in Godot and press F6 (Run Current Scene), or run from the terminal:

```
godot --headless --path GameProject res://tests/verify.tscn
```

All 54 checks should print PASS.

Every level is checked by `tools/level_solver.py` (Python 3): `python3 tools/level_solver.py check-all` prints the minimum number of mirrors for each chapter.

To build the Android APK: Project в†’ Export в†’ Android в†’ Export Project (debug keystore, Godot 4.7.2 Android templates).

To build the game for iPhone:

1. Open the project in Godot on a Mac and install the export templates for Godot 4.7.2 (Editor в†’ Manage Export Templates).
2. Open Project в†’ Export, select the iOS preset, and check the app details (bundle ID `com.mt2402.aura`, your Team ID).
3. Export the project and open the generated `AURA.xcodeproj` in Xcode. Under Signing & Capabilities, select your Apple team for code signing.
4. Connect your iPhone, select it in Xcode, and click Run.
5. On the iPhone, trust the developer once: Settings в†’ General в†’ VPN & Device Management.

## How to play

**Goal:** Your goal is to light up every star on the board with a single beam. Stone walls stop the light, and each chapter gives a limited number of mirrors.

**Gameplay loop:** Place a mirror в†’ Rotate it в†’ Watch the beam в†’ Adjust в†’ Light every star в†’ Complete the chapter.

**Controls (touch):**

- Tap an empty cell вЂ” place a crystal mirror
- Tap a mirror вЂ” select it
- Round arrow icons (right side) вЂ” turn the selected mirror by 45В°
- Undo / Delete / Reset icons (left side) вЂ” undo the last action, remove the selected mirror, clear the board
- Light bulb icon вЂ” hint (1 free per chapter; a demo "rewarded ad" gives one more)
- Pause icon (top-left corner) вЂ” Resume, Restart, Chapters, Settings, Main menu
- Main menu: tap the lightkeeper to change her mood (happy в†’ sad в†’ surprised в†’ calm)
- Optional: Tilt to rotate (Settings) вЂ” tilt the phone left or right to turn the selected mirror

**3 stars:** Complete a chapter with the minimum number of mirrors (found by the level solver) and no hints. One extra mirror costs a star, using hints costs a star (minimum 1 star). Each chapter allows only one mirror more than the minimum.

## What changed since Assignment 2

After Assignment 2, we improved the game based on feedback and phone testing:

- Small buttons and text, purple text on a purple background в†’ bigger buttons (100 px), text at least 22 px, dark text on light panels
- Three sound effects with unknown authors and licences в†’ replaced with Kenney CC0 sounds (credited); own music made in GarageBand. For the final (A5) we replaced them with 11 Freesound sounds chosen by our team (credited below)
- Unclear AI use; AI-made assets and code-drawn animation в†’ animation moved to editor scenes (AnimationPlayer, sprite frames); all AI use is listed in [Use of AI tools](#use-of-ai-tools)
- Win panel covered the lit star, no pause after leaving the app, black side bars, no sound on silent mode в†’ 1.5 s panel delay, pause on focus loss, full-width layout, Playback audio session

## What changed in Assignment 4

- Assignment 3 feedback (UI): the board now fills most of the screen; text buttons were replaced with round icon buttons on a layer over the board; the title, stars and mirror count are small chips; tips are short toasts.
- Assignment 3 feedback (difficulty): 8 chapters instead of 2, stone walls, a mirror limit and stricter stars. Every level is checked by a solver; most have one to four possible minimum solutions.
- Animated background (drifting scenery, glowing moon, fireflies), vibration feedback, optional tilt controls, chapter select with stars, demo rewarded ad, built-in performance test (Settings в†’ Performance test).

All feedback (instructor and players), what we changed and how we checked it: [FEEDBACK.md](FEEDBACK.md).

## Final version (in progress)

- **Languages:** English, Russian and Kazakh (Settings в†’ Language; the phone's language is used by default). All interface texts are in `localization/aura.csv`; story texts have `_ru` / `_kk` fields in `story/season1.json`.
- **Story:** season 1 "Frieren's Way Home" вЂ” a prologue and 8 episodes, one per chapter: Lira the lightkeeper helps Frieren, a fallen star, find her sisters and fly home. Each episode plays over a scene made by our team in Canva (`story/scenes/`, built with Canva library illustrations) and ends with a choice.
- **Levels:** 8 hand-made chapters on a 14 Г— 7 board, one new idea each: one turn в†’ one beam through two stars в†’ find the only gap в†’ reach a star from behind в†’ the beam crosses its own path в†’ a spiral в†’ a staircase of stars в†’ a big loop. Each chapter shows its idea as a short tip; `tools/level_solver.py check-all` confirms the minimum number of crystals (7 of 8 chapters have exactly one solution).
- **Fewer words:** menus, pause, win panel, shop and settings use picture buttons (icons in `assets/ui/icons/`); texts are short and shrink to fit in every language.
- **Aura:** the in-game currency (earned for new stars, the daily light and story choices; spent in the Shop on hints, extra crystals, prisms and skins). No real money.

## Mobile interface

- **Buttons:** Large 100 px buttons in one row at the bottom; Rotate buttons on the right, under the thumb.
- **Pause:** Pause button in the top-right corner opens Resume, Restart, Settings and Main menu. The game pauses automatically when you leave the app.
- **Win panel:** Appears 1.5 s after the last star lights up and shows reward stars, mirrors used, and Try again / Main menu / Next chapter.
- **iPhone screen:** The layout is centred and the background fills the full width, so there are no black bars. Nothing goes under the Dynamic Island or the home bar.

## How it works

Light beam and reflections (file: `scripts/game_scene.gd`, function: `_recalculate_rays()`):

1. **Start the beam:** The beam starts at the sun and goes down.
2. **Find the nearest hit:** The code finds the closest mirror on the beam's path, or the board edge.
3. **Reflect:** The beam bounces off the mirror at a new angle and continues (max 64 bounces).
4. **Check the stars:** Every star the beam passes through lights up. When all stars are lit, the chapter is complete.

## Project structure

- `project.godot` вЂ” file used to open the project
- `scripts/` вЂ” code that manages the game
- `scenes/` вЂ” screens and core parts of the game
- `scenes/pieces/` вЂ” individual game items
- `levels/` вЂ” level data
- `assets/` вЂ” images, music and sounds
- `tests/` вЂ” automated checks
- `tools/level_solver.py` вЂ” level solver and generator

## Testing

- **Device:** iPhone 14 Pro, iOS 26.6
- **What we tested:** 16 checks on the real iPhone (mirrors, undo, hints, pause, app switch, rotation, saving, sound) + 34 automated checks in Godot
- **Found and fixed:** win panel hid the lit star в†’ 1.5 s delay; no pause after leaving the app; black side bars; no sound on silent mode вЂ” all fixed and re-tested
- **What's left:** only 2 chapters; the development build must be reinstalled every 7 days

## Known limitations and unfinished work

- Currently, 2 chapters out of the planned 25 are ready.
- The iPhone application needs to be re-signed every seven days (the development build must be reinstalled every 7 days).

## Credits and licences

**Sounds** вЂ” chosen by our team on Freesound (freesound.org), then trimmed, levelled and converted to OGG for the game (`assets/audio/sfx/`):

| File | Used for | Sound and author | Licence |
|---|---|---|---|
| `place.ogg` | placing a crystal | "Wine glasses cheers" by Mega-X-stream вЂ” https://freesound.org/people/Mega-X-stream/sounds/429028/ | CC BY 4.0 |
| `rotate.ogg` | turning a crystal, tapping the lightkeeper | "Pluck 1" by nomiqbomi вЂ” https://freesound.org/people/nomiqbomi/sounds/578807/ | CC0 1.0 |
| `delete.ogg` | removing a crystal | "Toggle off (Soft UI SFX Free)" by heyheytheree вЂ” https://freesound.org/people/heyheytheree/sounds/871928/ | CC BY 4.0 |
| `click.ogg` | buttons, typing in story episodes | "Soft UI Button Click" by Jummit вЂ” https://freesound.org/people/Jummit/sounds/528561/ | CC0 1.0 |
| `error.ogg` | not allowed (crystal limit, locked chapter) | "Error buzz (Soft UI SFX Free)" by heyheytheree вЂ” https://freesound.org/people/heyheytheree/sounds/871919/ | CC BY 4.0 |
| `star.ogg` | a star lights up, reward stars | "SingleDing" by NoisyRedFox вЂ” https://freesound.org/people/NoisyRedFox/sounds/759839/ | CC0 1.0 |
| `whoosh.ogg` | pop-up windows | "Magical Airy Transition-Riser" by mikiko850 вЂ” https://freesound.org/people/mikiko850/sounds/848208/ | CC BY 4.0 |
| `pop.ogg` | prism, extra crystal, rewards | "Bubble_Pop" by arttim вЂ” https://freesound.org/people/arttim/sounds/733264/ | CC0 1.0 |
| `win.ogg` | completing a chapter | "Item Get" by Qvantor вЂ” https://freesound.org/people/Qvantor/sounds/878616/ | CC0 1.0 |
| `coins.ogg` | aura (in-game currency) earned or spent, daily light | "Coin Collect" by Qvantor вЂ” https://freesound.org/people/Qvantor/sounds/878612/ | CC0 1.0 |
| `story_line.ogg` | a new line in a story episode | "C4.wav" by joesh2 вЂ” https://freesound.org/people/joesh2/sounds/577691/ | CC0 1.0 |

CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ В· CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/

**Music** вЂ” assembled by us in Apple GarageBand with the "Set Free Melodic Synth" loop and the Grand Piano instrument, used under the GarageBand licence.

**Art** вЂ” The lightkeeper (`assets/art/lightkeeper/`, 8 frames) and the board pieces (crystal, lit and dim stars, sun, sparkle, stone wall in `assets/art/pieces/`) were assembled and edited by our team in Canva. The starting point was a shape template of our Assignment 2 elf-mage (`tools/photoshop/`, see [Use of AI tools](#use-of-ai-tools)); in Canva we changed the colours, shapes and details, and drew the stars, sun, sparkle and wall ourselves. The character faces were drawn for us by Elizaveta Krasnoshchekova, used with permission. The background scenery (`assets/art/background/scenery.png`) was made by our team in Canva for the final version, from Canva library illustrations. The star-dust layers (`dust_a/b/c.png`) are simple dots drawn by `tools/make_star_dust.py`. The UI icons are in `assets/ui/icons/`. 

**Engine and fonts** вЂ” The game is made in Godot. Engine licence вЂ” MIT: https://godotengine.org/license/ The standard Godot font is used for the interface. The AURA title uses Cinzel by The Cinzel Project Authors (https://github.com/NDISCOVER/Cinzel), SIL Open Font License 1.1 (`assets/fonts/Cinzel_OFL.txt`).

**Inspiration** вЂ” We were inspired by the atmosphere of Frieren, the calm style of Monument Valley, and Portal puzzles. Their images, music, and other ready-made materials were not used in the project.

## Use of AI tools

All use of AI in this project is listed here, in one place.

| Tool | What it was used for | Where |
|---|---|---|
| Claude Code | Automatic tests, written at our request and then tested by us | `scripts/`, `tests/` |
| Claude Code | Shape template of the Assignment 2 character | `tools/level_solver.py`, `levels/`, `tools/make_star_dust.py`, `tools/photoshop/` |
| Claude Code | Simple vector UI icons | `assets/ui/icons/` | 

Our team's work:

- Elmira designed the mechanics and the levels.
- Khalida created the interface and the game flow.
- Diana created the visuals, animations and sound.
- The character, board pieces, story scenes and background were assembled and edited by the team in Canva; the faces were drawn by Elizaveta Krasnoshchekova (with permission).
- We chose the sounds on Freesound, made the music in GarageBand, chose and edited the story, ran playtests and tested the builds on our phones.
