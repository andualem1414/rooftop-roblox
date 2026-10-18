# Rooftop (Roblox) — TODO

How to use: add ideas under **Inbox**, move them to **Next up** when we commit to them, tick them off (`- [x]`)
when done and move them to **Done** with the date. Each phase ends with a playtest the user does and approves.
Ask Claude "what's on the todo list?" or "do the next todo" any time.

## Next up

Phase 1 — Setup (playtest: Rojo syncs into Studio, both "hello" lines show in Output, MCP connected)

- [x] 2026-10-18 — Toolchain with Rokit: Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0, Lune 0.10.5 (`rokit.toml`)
- [x] 2026-10-18 — Rojo project: two places (`race.project.json`, `lobby.project.json`) sharing `src/shared`
- [x] 2026-10-18 — Lune test runner (`lune run tests`), `Config.luau` with the original's numbers
- [ ] Studio MCP connected (Studio → Assistant → Manage MCP Servers), so Claude can run playtests
- [ ] Rojo plugin installed, `rojo serve race.project.json` connected to an empty Baseplate, hello lines in Output
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
- **Third person** with over-the-shoulder aim; the floors above you are **cut away** like the original.
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
