# Rooftop (Roblox)

The Roblox version of Rooftop, the browser game live at https://imaginatingg.itch.io/rooftop. Climbers race up a
20-floor tower on moving platforms, fight on the way, and the first one alone on a platform through the roof wins.
The plan, the history and every decision are in `TODO.md`.

**The original is a read-only reference:** `C:\Users\Andualem\Documents\Projects\rooftop` (three.js + Rapier +
Supabase). Read it for numbers and behaviour; never edit, commit or push anything there.

## Layout

One Roblox experience, two places, one repo:

- `race.project.json`: the **Race** place, where one race is played (reserved servers, 20 climbers).
- `lobby.project.json`: the **Lobby** place, the start place: forecourt, countdown, sends groups into races.
- `src/shared` → `ReplicatedStorage.Shared` in both places. Pure game logic and numbers (`Config.luau`), no
  Roblox services where it can be avoided, so `tests/` can run it under Lune. Use `require("./X")` between shared
  modules (works in both Roblox and Lune); avoid `init.luau` in `src/shared`.
- `src/server/race`, `src/server/lobby` → `ServerScriptService.Race` / `.Lobby`.
- `src/client/race`, `src/client/lobby` → `StarterPlayer.StarterPlayerScripts.Race` / `.Lobby`.
- `tests/`: Lune specs for `src/shared` (`*.spec.luau`, listed in `tests/init.luau`).

Code is Luau with `--!strict` where practical, formatted with StyLua (tabs, 120 columns), linted with Selene.

## Toolchain

Rokit manages the tools, pinned in `rokit.toml` (Rojo, StyLua, Selene, Lune). On a new machine: install Rokit,
then `rokit install` in this folder. Tools are in `%USERPROFILE%\.rokit\bin` (on PATH for new terminals).
If Rokit fails with "reqwest middleware error", an antivirus with HTTPS scanning is in the way (it happened with
Avast): pause it for the install.

```
lune run tests                         # the shared-logic tests
selene src                             # lint
stylua src tests                       # format (stylua --check src tests to only check)
rojo serve race.project.json           # live sync into Studio (port 34872; lobby uses 34873)
rojo build race.project.json -o build/race.rbxl
```

## Studio

- Rojo plugin: `rojo plugin install` (Rojo 7). In Studio: Plugins → Rojo → Connect while `rojo serve` runs.
- Studio's built-in MCP server lets Claude run playtests, run Luau and read Output: in Studio, Assistant → … →
  Manage MCP Servers → *Enable Studio as MCP server*, then quick-connect Claude Code (Assistant Settings → MCP
  Servers). The MCP tools load when a Claude session starts. Docs: https://create.roblox.com/docs/studio/mcp
- Multiplayer test: Test → Clients and Servers (2–4 clients). Teleports and reserved servers don't work in Studio;
  the race place is playable on its own there (bots fill the round), the lobby → race move is tested in the
  published, still-private game.

## Rules for working here

- Server-authoritative: the server owns rounds, platforms, health, hits, ammo and wins. Clients send intent through
  RemoteEvents; the server validates every shot and swing (range, rate, line of sight).
- Write our own weapon code. No Toolbox gun kits or free models with scripts. Roblox-made sounds from the Creator
  Store audio library are fine (asset IDs only).
- Check create.roblox.com/docs for current APIs and limits before using them; don't rely on memory.
- Commit after each working step (`main` branch). The GitHub repo is private and created by the user.
- The user signs in, verifies, accepts terms, pays, fills in the maturity questionnaire and makes the game public.
  Ask before anything public or hard to undo.
- An Open Cloud API key, if one is needed, lives in an environment variable the user sets. Never ask for it, print
  it, log it or commit it.

## Publishing

Not set up yet (phase 7). Steps will go here.
