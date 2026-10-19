# Rooftop (Roblox) — TODO

How to use: add ideas under **Inbox**, move them to **Next up** when we commit to them, tick them off (`- [x]`)
when done and move them to **Done** with the date. Each phase ends with a playtest the user does and approves.
Ask Claude "what's on the todo list?" or "do the next todo" any time.

## Next up

What's left is mostly the user's: looking, playing and publishing. Claude's code for every phase is in.

- [ ] **The user's look** (screenshots) and the pick of a look preset (Neon Night is the default)
- [ ] **Playtest by the user** in Studio (Test → Clients and Servers, 2–4 players): the race place
      (guns, full auto, touch / controller buttons, sounds, settings, looks on bots) and the lobby place
      (open `build/lobby.rbxl`; see CLAUDE.md → Studio), then fixes
- [ ] Listen to the sounds and swap any that don't fit (`src/shared/Sounds.luau`: one table, ids and trims)
- [ ] **Publish privately** (phase 7, `publish/RELEASE.md`), fill in `src/shared/Places.luau`, then the
      release test in the published game: teleports, saving, leaderboards, friends together
- [ ] **Phase 6: Robux items**: the user decides whether to sell anything (cosmetic only, never pay-to-win)
- [ ] Then: the maturity questionnaire (expected Mild), the game page, icon and thumbnails, going public

## Roadmap

1. **Setup**: toolchain, Rojo syncing into Studio, MCP, GitHub. *Done.*
2. **First playable (race place)**: the tower, platforms, the bat + pistol, the roof win, bots. *Built; waiting
   for the user's look and playtest.*
3. **Full game**: the lobby place and the reserved-server races, all weapons and ammo, balance, bots, HUD,
   round flow, menus, settings, sound and music; phone, tablet, PC and console controls. *Built and checked in
   Studio; teleports can only be tested once published.*
4. **The look**: night forest valley, ink style, the climber look and the 10 looks. *Done (the looks are worn
   over your own avatar).*
5. **Saved data**: stats, unlocks, leaderboards (DataStores + OrderedDataStores). *Built; data stores only run
   once published.*
6. **Robux items**: decide later (only cosmetic, nothing pay-to-win; ask first). *Waiting for the user.*
7. **Publishing**: game page text, icon, thumbnails, maturity questionnaire answers (aim: Mild), release
   checklist. *Kit ready in `publish/RELEASE.md`; the publishing itself is the user's.*

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

## Decisions (2026-10-19)

- **Start with the bat and a pistol** (12 + 48 rounds); you come to with them too. The rifle (full auto, long
  range), SMG (full auto, short range) and shotgun (eight pellets that land as one blow, never a one-shot
  knock-out) are found: a third of platforms carry a gun (rifle 36 %, SMG 36 %, shotgun 28 %), about half the
  floors start with a weapon lying there (40 % swords, the rest found guns).
- **Fire is our own input** (tools are ManualActivationOnly): left mouse / R2 / a touch Fire button; hold for
  full auto. Touch also gets Aim (a switch), Reload and Swap buttons; Q / Y swaps; B picks up on a controller
  (X reloads). On touch or a controller you face where the camera looks while holding a gun.
- **The lobby is a plaza at the end of the walkway**, looking at the very tower you'll climb. The countdown is
  on the screen and on a big board; leaderboards and the rules stand round the plaza.
- **Friends together**: joining a friend from Roblox's friends list lands you in their lobby, and the whole
  lobby goes together. No party system of our own.
- **A race server runs one race** for its group, then sends everyone back to the lobby.
- **Looks are worn over your own avatar** (your face, skin and hair stay yours); "Your avatar" is the default.
  The original's ten looks and unlock rules; bots wear them too.
- **Profiles** (stats, look, settings) in one DataStore key per player, changed with UpdateAsync; three
  leaderboards: most escapes, most knock-outs, fastest escape.
- **Sound**: only Roblox's own licensed library on the Creator Store (ProSoundEffects, APM Music) and the sounds
  that ship with Roblox; long recordings are trimmed to the bit we want (measured in Studio).
- **Settings**: music, effects, mouse sensitivity, camera shake, damage numbers; kept with the profile.

## Inbox

- Lighting → Technology = Future has to be set by hand in Studio (scripts can't); remember it for the
  published places
- Floors "double the size": read as 24 × 24 m (each side doubled; 4× the area). The other reading is double the
  area (~17 × 17 m). Confirm in the playtest.
- The original's own sounds (wind, the platform's clunk, the hatch grinding, confetti cannons), made with Web
  Audio: render them to files for the user to upload, if the library sounds don't fit
- Controller navigation in the menus (the panels work with a mouse and touch; a controller opens settings with
  View, but moving through the panels needs Roblox's UI selection set up)
- The winner's skydive (kept for a later phase in the 2026-10-18 decisions)

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

- [x] 2026-10-19 — Private GitHub repo: `origin` = github.com/andualem1414/rooftop-roblox, `main` pushed
- [x] 2026-10-19 — Phase 2 clean-up: the Studio-only helpers (`RooftopDev`, the "went down" line) were already
  behind `IsStudio()`; bots' `BotMode` attribute now is too
- [x] 2026-10-19 — Phase 3 weapons: rifle, SMG, shotgun (models, colours, pickups showing the real weapon), full
  auto, pellets as one blow; bots fire bursts, close in with a shotgun, swap up to better guns
- [x] 2026-10-19 — Phase 3 controls: one fire path for mouse, controller and touch; Fire / Aim / Reload / Swap
  touch buttons; Q / Y swap; facing the camera with a gun on touch and controller
- [x] 2026-10-19 — Phase 3 lobby place: the plaza, countdown (45 s, 5 s at 20), reserved race servers with the
  group's size in the teleport data, retries, stragglers to the same server, back to the lobby after the race
- [x] 2026-10-19 — Phase 3 menus, settings, sound and music (lobby: how to play, looks, stats, leaderboards,
  settings; race: Settings / P / View)
- [x] 2026-10-19 — Phase 4: the ten looks (worn over your avatar); bots wear them
- [x] 2026-10-19 — Phase 5: profiles, leaderboards, Escapes / KOs in the player list
- [x] 2026-10-19 — Phase 7 kit: `publish/RELEASE.md` (steps, release test, questionnaire answers, game page)
- [x] 2026-10-19 — Fixed: bots lost their spare weapon (it fell out of the world from a stash inside the
  character); the valley's grass lay 2 studs over the concrete at the tower's foot
- [x] 2026-10-19 — Checked through the Studio MCP and screenshots: race (firing, full auto 30 → 24 in a second,
  swap, reload, bots keeping both weapons, a bot picking up an SMG), lobby (countdown, the Studio message at
  zero, wearing The Climber, a locked look refused, the plaza and boards on screen); no script errors in Output
- [x] 2026-10-18 — Read the original (CLAUDE.md, TODO.md, src) and summarized loop, numbers and look

Phase 2 — First playable

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
- [x] 2026-10-18 — **Feel and look overhaul** (the user asked for it before phase 3; it pulls most of phase 4
  forward): posed arms for every climber (guns aimed in both hands with recoil, real bat / sword swings with
  trails, guard, reload, flinch, run lean, banking) on an IK solver over Roblox's animations; muzzle flashes
  that light the room, tracers, brass, sparks, impact stars, popping damage numbers, knock-out bursts, camera
  recoil and shake, hit markers, hurt vignette; ink outlines on climbers; three look presets (Neon Night
  default, Golden Dusk, Moonlit Ink); the forest valley (terrain, mountains, pond, track, 260 pines, the
  tower's foot and entrance, ROOFTOP letters on the hill); 20 themed floors with furniture as cover; a
  dressed roof; the intro (orbit / crane / rocket, then the dive), the roof-opening shot, fireworks and
  confetti for the win

Phase 1 — Setup

- [x] 2026-10-18 — Toolchain with Rokit: Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0, Lune 0.10.5 (`rokit.toml`)
- [x] 2026-10-18 — Rojo project: two places (`race.project.json`, `lobby.project.json`) sharing `src/shared`
- [x] 2026-10-18 — Lune test runner (`lune run tests`), `Config.luau` with the original's numbers
- [x] 2026-10-18 — Studio MCP: enabled in Studio, added to Claude Code for this folder
  (`claude mcp add --transport stdio Roblox_Studio -- cmd.exe /c C:\Users\Andualem\AppData\Local\Roblox\mcp.bat`,
  run from PowerShell: Git Bash turns `/c` into `C:/`). Tools load in the next Claude session
- [x] 2026-10-18 — Rojo plugin in Studio, connected to `rojo serve race.project.json` on a Baseplate
- [x] 2026-10-18 — Playtest passed: both hello lines in Output on Play (server and client)
