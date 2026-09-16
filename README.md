# Cops & Robbers

Standalone multiplayer top-down "Cops & Robbers" MVP, built in [Godot 4](https://godotengine.org/) (GDScript). 10 players split into two teams of 5 — cops vs. robbers — on one small fixed map. Robbers complete crimes for points, cops capture robbers for points, highest score when the 5-minute timer runs out wins.

This is an intentionally small MVP: the goal is a complete, working core loop first. See "Scope" below before adding anything not in the original spec.

## Why Godot

The project targets an eventual Steam release, so it's built directly in the real target engine instead of a browser stack that would later need a full rewrite. Godot exports to native standalone binaries (Windows/Mac/Linux) and has first-class Steam support via GodotSteam when that step is needed.

## Architecture

- **Authoritative server.** One peer (the host) runs the real simulation — movement, crime progress, captures, scoring, the match timer. Clients only send *input* (movement vector, button states), never positions. The server clamps/validates everything it receives, so a modified client cannot move faster or fake an outcome.
- **Client-side prediction & interpolation.** The local player moves immediately in response to input (prediction) and snaps back if it drifts too far from the server's authoritative position. Other players' avatars are smoothed by lerping toward the latest position the server broadcast (interpolation).
- **Networking.** Godot's high-level multiplayer API over `ENetMultiplayerPeer` (native UDP), default port `7777`. No browser/WebSocket layer — this is a real standalone build.
- **No imported art.** Every visual (players, walls, crime-spot zones) is drawn procedurally (`_draw()` / `Polygon2D`), and gameplay nodes are built in code rather than hand-authored `.tscn` files. This keeps the project entirely text-based and easy to diff/review without the Godot editor. `scenes/Main.tscn` is the only scene file, purely because `run/main_scene` requires one.

## Project layout

```
project.godot
scenes/Main.tscn              entry point scene (single Node + script)
scripts/
  main.gd                     boots the window, world, camera, and swaps UI per game state
  autoload/
    input_setup.gd            registers input actions (WASD/arrows, E, F, Space) in code
    net.gd                    ENet connection lifecycle (host/join/disconnect)
    game_manager.gd           authoritative game state & simulation (the core of the game)
  entities/
    player_avatar.gd          CharacterBody2D for a player (movement, rendering)
    crime_spot.gd              Area2D for a crime location (progress ring rendering)
  world/
    map_builder.gd             builds the fixed arena: walls, obstacles, crime spots, spawns
  ui/
    main_menu_ui.gd            host/join screen
    lobby_ui.gd                connected players + "start game" (host only)
    game_hud.gd                timer, scoreboard, contextual prompts, ability cooldown
    victory_ui.gd               winner screen + "return to lobby" (host only)
```

## Running

Requires the Godot 4.3+ editor/binary (not included in this repo).

- **Play normally:** open the project in Godot and run it, or run the exported/editor binary from the project root. Pick "Host" on one instance and "Join" (with the host's IP) on others.
- **Dedicated headless server** (no window, just simulation — useful for a real server host): 
  ```
  godot --headless -- --dedicated-server
  ```
- **Auto-join a server headlessly** (useful for scripted testing):
  ```
  godot --headless -- --autojoin=127.0.0.1
  ```

## Controls

- Move: `WASD` / arrow keys
- Robbers — perform crime: hold `E` while standing inside a crime zone
- Cops — capture: hold `F` near a robber
- Ability (dash for cops, smoke for robbers): `Space`

## Scope (MVP)

Implemented per the original spec: real-time authoritative movement, lobby + automatic 5v5 team split, 4 fixed crime points with a 10s hold / 20s cooldown, cop captures with a 15s respawn, one ability per team, 5-minute match timer, live scoreboard, and a win screen.

Not implemented, and intentionally out of scope until discussed: sound, richer visual polish/menus, matchmaking across multiple concurrent rooms, and anything engine-level toward the Steam build (achievements, GodotSteam integration, etc.).
