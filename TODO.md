# Rooftop (Roblox) — TODO

How to use: add ideas under **Inbox**, move them to **Next up** when we commit to them, tick them off (`- [x]`)
when done and move them to **Done** with the date. Each phase ends with a playtest the user does and approves.
Ask Claude "what's on the todo list?" or "do the next todo" any time.

## Next up

Phase 2 — First playable (playtest: the user, with 2–4 players in Studio's "Clients and Servers" test)

- [x] 2026-10-18 — Shared logic with tests (39): platform timetable, combat (melee, blocks, guns, ammo, headshots
  1.5×, regen), rules (start floors 1–5, come to 2–5 lower, loot, only one can escape, phases)
- [x] 2026-10-18 — Tower: 20 floors of 24 × 24 m (1 m = 3 studs), windows, cover (half walls, barriers, loose
  crates), a lamp per floor, roof with a sliding hatch; shaft gates so nobody falls down the shaft
- [x] 2026-10-18 — Platforms on the original's timetable (every 17 s, 0.6 s a floor, 3 s stops), physical decks
  that carry riders; the roof rule: more than one rider as it leaves the top floor → all thrown off, "Only one
  can escape!"; alone → up through the roof → wins. Each platform carries a gun, a sword or ammo
- [x] 2026-10-18 — Weapons as Roblox tools (1 = bat, 2 = pistol): server-timed swings, server-checked shots
  (rate, ammo, camera ray near your head, line of sight from your gun, range), guard on right mouse with a
  melee weapon, aim over the shoulder on right mouse with a gun, R reloads, E picks up / swaps
- [x] 2026-10-18 — Bots fill to 20: catch platforms, ride, fight back, shoot at range, swing up close, pick up
  ammo and swords, fight other riders on the top-floor platform once the roof is open
- [x] 2026-10-18 — Race flow: ready (5 s frozen) → climb → roof opens 4:00 → over (a winner, or 8:00) → 15 s →
  next race (Studio; phase 3 sends players back to the lobby). Knock-outs: down 3.4 s, come to 2–5 floors lower
- [x] 2026-10-18 — Plain HUD: clock, floor, next platform, health, ammo, crosshair, banners, kill feed;
  floors above you cut away; muzzle flash, streak, impact marks, damage numbers
- [x] 2026-10-18 — Checked through the Studio MCP: a full race to a bot's escape, the throw-off, the next race,
  player shots reaching the server (12 → 9 rounds); no errors in Output
- [x] 2026-10-18 — Shooter camera for mouse players (see Decisions). Checked through the MCP: Scriptable camera,
  over the right shoulder, you face where it looks; turning with the mouse needs a real mouse (the MCP's
  simulated mouse can't move a locked cursor)
- [ ] **Playtest by the user** with 2–4 players (below), then fixes
- [ ] Studio-only helpers to remove or keep behind `IsStudio()`: `ServerStorage.RooftopDev` (skip the clock), the
  `BotMode` attribute on bots, the "went down" log line

Phase 1 — Setup (playtest: Rojo syncs into Studio, both "hello" lines show in Output, MCP connected)

- [x] 2026-10-18 — Toolchain with Rokit: Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0, Lune 0.10.5 (`rokit.toml`)
- [x] 2026-10-18 — Rojo project: two places (`race.project.json`, `lobby.project.json`) sharing `src/shared`
- [x] 2026-10-18 — Lune test runner (`lune run tests`), `Config.luau` with the original's numbers
- [x] 2026-10-18 — Studio MCP: enabled in Studio, added to Claude Code for this folder
  (`claude mcp add --transport stdio Roblox_Studio -- cmd.exe /c C:\Users\Andualem\AppData\Local\Roblox\mcp.bat`,
  run from PowerShell: Git Bash turns `/c` into `C:/`). Tools load in the next Claude session
- [x] 2026-10-18 — Rojo plugin in Studio, connected to `rojo serve race.project.json` on a Baseplate
- [x] 2026-10-18 — Playtest passed: both hello lines in Output on Play (server and client)
- [ ] Private GitHub repo (the user creates it), `git push`

## Roadmap

1. **Setup** — toolchain, Rojo syncing into Studio, MCP. (above)
2. **First playable (race place)** — the tower (20 floors of 24 × 24 m), moving platforms, climbing floors, the
   bat + one gun, the roof win with the one-rider rule, bots filling to 20, with 2–4 players in Studio's
   "Clients and Servers" test.
3. **Full game** — the lobby place and the reserved-server races, all weapons and ammo, balance, bots, HUD, round
   flow, menus, settings, sound and music; phone, tablet, PC and console controls.
4. **The look** — night forest valley, ink style, the climber look and the 10 looks.
5. **Saved data** — stats, unlocks, leaderboards (DataStores + OrderedDataStores).
6. **Robux items** — decide later (only cosmetic, nothing pay-to-win; ask first).
7. **Publishing** — game page text, icon, thumbnails, maturity questionnaire answers (aim: Mild), release checklist.

## Decisions (2026-10-18)

The flow
- Press Play → a **lobby** (the forecourt in front of the tower). Lobby servers hold **20**.
- A **45 s countdown** starts with the first player in; it drops to 5 s when 20 are waiting. At zero, **everyone in
  the lobby goes** (no opting out) into a fresh **reserved server** of the Race place; bots fill up to **20
  climbers**. Players who arrive meanwhile wait in a lobby for the next countdown. Reserved servers are Roblox's
  (free, nothing to host).
- **Friends** who play together go into the same race, from the start.
- Everyone starts **spread over floors 1–5**.
- **Knocked out:** down for a few seconds, then you come to **2–5 floors lower** with the bat (like the original).
- **Disconnect mid-race:** gone, one climber fewer (no bot replaces them).
- **The roof opens at 4:00.** The first climber to ride a platform up through the roof **alone** wins. If more than
  one climber is on the platform as it reaches the roof, it **throws them all off** and says *"Only one can
  escape."* Then a **15 s celebration** (confetti, fireworks), then everyone back to the lobby.
- **8 min limit:** nobody out by then → the race ends with no winner.
- Keep: crates you can shove, weapons lying on floors at the start, the roof-opening cut-scene, confetti and
  fireworks, the opening camera shots. The winner's **skydive** stays, in a later phase.

Weapons
- **Gun-based game.** Melee: **sword** and **bat** only (knife, spear, axe, hammer dropped). Everyone starts with the
  **bat** and comes back with it.
- Guns: **pistol, full-auto rifle, shotgun, SMG**. **Hitscan** from the camera through the crosshair, drawn-style
  muzzle flash and impact marks. No real gun brand names, no blood or gore.
- **Ammo:** generous at the start, it runs out, and ammo is found on different floors.

Camera, look, sound
- **Third person** with over-the-shoulder aim; the floors above you are **cut away** like the original. Camera
  occlusion is Roblox's "Zoom" (Invisicam faded the floor under your feet, 2026-10-18).
- 2026-10-18: **Shooter camera with a mouse** (our own camera, `CameraAim.luau`): the mouse always turns the
  view (cursor hidden, crosshair in the middle), you face where you look, you swing and shoot toward the
  crosshair, the wheel zooms; right mouse = aim with a gun, guard with a melee weapon (no more conflict with
  Roblox's hold-right-click-to-look). The cursor comes back in menus / chat / while Left Alt is held. Touch
  and controller keep Roblox's own camera.
- Setting: the **forest valley** of the original (pines, mountains, cold moon), not a city.
- Music: **replace the soundtrack for now** (rights unclear). Sound effects: a **mix** of the original's sounds
  rendered to files and Roblox's own audio library.
- Maturity target: **Mild**. Owner: the user's **personal account**. Name: **Rooftop**.

## Inbox

- Floors "double the size": read as 24 × 24 m (each side doubled; 4× the area). The other reading is double the
  area (~17 × 17 m). Confirm in the phase 2 playtest.
- What do you start with besides the bat: a pistol with generous ammo? A melee slot + a gun slot? (Decide before
  phase 2's gun.)
- How common guns and ammo boxes are on platforms and floors (the original: a gun on 1.5% of platforms).
- Friends together: the lobby needs to pull a friend into your lobby server (or a party queue); check what Roblox
  offers.

## Roblox limits to remember (checked 2026-10-18, create.roblox.com/docs)

- **Highlight:** at most 255 shown at once on a client; disabled ones still count (destroy instead).
- **DataStores (per server, per minute):** read/write 60 + 40 × players; ordered write 30 + 5 × players; ordered
  list (GetSortedAsync) 5 + 2 × players, 100 per page. Keys/names 50 chars; value up to 4 MB; per key 4 MB/min
  written. UpdateAsync counts as a read and a write.
- **Audio uploads:** 100 per 30 days unverified, 2,000 ID-verified; < 20 MB, < 7 min, mp3/ogg/wav/flac, ≤ 48 kHz.
  Only audio we have the rights to.
- **Teleports:** server-side `TeleportAsync` with `TeleportOptions.ShouldReserveServer`; don't work in Studio;
  handle `TeleportInitFailed`, retry with pcall; teleport data is visible to the client (nothing secret in it).
- **Maturity:** repeated unrealistic violence with no blood = Mild; realistic injuries would make it Moderate.

## Done

- [x] 2026-10-18 — Read the original (CLAUDE.md, TODO.md, src) and summarized loop, numbers and look
