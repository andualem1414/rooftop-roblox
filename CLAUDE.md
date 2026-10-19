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
- `src/server/common` → `ServerScriptService.Common` in both places: the tower, the valley world, collision
  groups, saved profiles (`ProfileStore`), looks (`LookService`) and teleports (`Travel`).
- `src/client/race`, `src/client/lobby` → `StarterPlayer.StarterPlayerScripts.Race` / `.Lobby`.
- `src/client/common` → `StarterPlayerScripts.Common` in both places: the UI kit, settings and audio.
- `src/client/first` → `ReplicatedFirst.Loading` in both places (the loading screen).
- Robux: only the boosters (`shared/Booster`, `server/race/BoostService`, `server/common/Purchases`); every
  purchase becomes a saved credit first, handed out once per PurchaseId.
- `tests/`: Lune specs for `src/shared` (`*.spec.luau`, listed in `tests/init.luau`).
- `publish/RELEASE.md`: publishing steps, the release test, questionnaire answers, the game page text.

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

- Rojo plugin: `rojo plugin install` (Rojo 7). On this machine that can't find Studio's registry keys, so the
  plugin was put in by hand: `Rojo.rbxm` from the matching Rojo release into `%LOCALAPPDATA%\Roblox\Plugins`
  (update it with the CLI version). In Studio: Plugins → Rojo → Connect while `rojo serve` runs.
- Studio's built-in MCP server lets Claude run playtests, run Luau and read Output: in Studio, Assistant → … →
  Manage MCP Servers → *Enable Studio as MCP server*, then quick-connect Claude Code (Assistant Settings → MCP
  Servers). The MCP tools load when a Claude session starts. Docs: https://create.roblox.com/docs/studio/mcp
- Lighting: the game sets **LightingStyle = Realistic** itself (`shared/Look` and the project files; the old
  Technology property is deprecated and needs no hand setting). How the light is shared out, and why rooms
  are lit by the moon and ambient with soft lamps, is in `shared/Look`'s header.
- Roblox rebuilds its lighting round `Camera.Focus` after a big camera move (measured 2.5–4 s, nearest
  surfaces first): set pieces keep the focus on the player and end on a title card (`client/race/Cinematic`).
- Look presets (Studio only): a Workspace string attribute `LookPreset` = "Neon Night" (default), "Golden Dusk"
  or "Moonlit Ink" switches the lighting live while playing.
- Fewer bots for a test: select Workspace in Studio, Properties → Attributes → add a number attribute
  `TestBots` (e.g. 3; 0 = none). Studio only; delete the attribute for a full race of 20.
- Skip the race clock in a test (Studio only): `game.ServerStorage.RooftopDev:Invoke("skip", seconds)` from the
  server command bar or the MCP's execute_luau. Also `("restart")` (end the race now), `("win")` (the first
  player gets out) and `("give", "rifle")` (the first player gets a weapon).
- A running playtest keeps the code it started with: stop and play again after a change. Rojo syncs file
  changes but not changes to a `*.project.json` tree: restart `rojo serve` after editing one (and reconnect).
- The lobby in Studio: `rojo build lobby.project.json -o build/lobby.rbxl`, open it in a second Studio window,
  `rojo serve lobby.project.json` (port 34873) and connect Rojo there on 34873. Each Studio window shows up
  separately in the MCP's list_roblox_studios.
- Saved data is off in Studio (it says so in Output) unless the place is published and *Enable Studio Access
  to API Services* is on. Then Studio writes to the real data stores.
- The MCP's screen_capture comes back blank on this machine; screenshots of the Studio window (computer use)
  show the game.
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

The full list is in `publish/RELEASE.md`. In short (the owner does the Roblox side):

1. Build both places.
2. Publish the lobby as a new experience **Rooftop** (the start place), then the race into the same
   experience as a new place named **Rooftop Race**.
3. Put both place ids in `src/shared/Places.luau`, commit, rebuild, publish both again.
4. Configure: max players 20 in both places, R15 avatars, devices, keep it private. Create the four boost
   Developer Products and put their ids in `src/shared/Booster.luau`.
5. Run the release test in the private game (teleports and data stores only work there).
6. Maturity questionnaire (expected: Mild), game page, icon and thumbnails, then public.
