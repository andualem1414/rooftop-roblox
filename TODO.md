# Rooftop (Roblox) — TODO

How to use: add ideas under **Inbox**, move them to **Next up** when we commit to them, tick them off (`- [x]`)
when done and move them to **Done** with the date. Each phase ends with a playtest the user does and approves.
Ask Claude "what's on the todo list?" or "do the next todo" any time.

## Next up

What's left is mostly the user's: looking, playing and publishing. Claude's code for every phase is in.

- [ ] **Playtest the new movement** (2026-10-19, built but not yet seen in Studio): strafing and backing
      off with a gun, turning on the spot, jumps and drops, a platform ride, every gun's stance, kick and
      reload (the magazine drop, the shotgun's shells and pump), melee swings and guards, being shot from
      each side, a boost and its landing, the skydive, a knock-out and coming to, the end of a race. The
      numbers to tune are in `client/race/Poser` (STANCE, RELOADS, the springs) and `client/race/Gunwork`
- [ ] **Look round the redesigned floors** (2026-10-21, built and checked by script in Studio, not yet
      seen): walk every floor (T wins, `RooftopDev` skips; a race starts you on floors 1–5) and say what
      to change. Each floor's design is one entry in `server/common/Themes` (finishes, plan, dressing);
      the furniture is in `PropsHome` / `PropsWork` / `PropsFun`
- [ ] **Check the camera in tight spots** (2026-10-19): backed against a wall, behind shelves, the roof's
      units; props ghost, walls don't, your silhouette shows if a wall still hides you
- [ ] **The user's look** (screenshots) and the pick of a look preset (Neon Night is the default)
- [ ] **Playtest by the user** in Studio (Test → Clients and Servers, 2–4 players): the race place
      (guns, full auto, touch / controller buttons, sounds, settings, looks on bots) and the lobby place
      (open `build/lobby.rbxl`; see CLAUDE.md → Studio), then fixes
- [ ] **Listen to the new sounds** (2026-10-20, every id loads and plays in Studio, nobody has heard them
      yet): each gun from close and from across the tower, a full-auto burst, reloads, the shotgun's pump,
      bullets past your head, bat and sword hits, the countdown beeps and clicks; the race music (a
      playlist), the roof's, the lobby's. Swap or retune in `src/shared/Sounds.luau` (ids, cuts, volumes)
- [x] **Published privately** (2026-10-19): experience **Rooftop** (universe 10771906434), lobby place
      96194017293551 (start place), race place 127585457284186 "Rooftop Race"; ids in `src/shared/Places.luau`;
      R15 only, max 20 per place, Studio API access on, access private
- [x] **Version 0.3.0 published** (2026-10-24): teams, platforms from the bottom and the polish since 0.2.0;
      race place version 13, lobby version 18 (the lobby's corner says 0.3.0)
- [ ] **Release test** in the published game (`publish/RELEASE.md` §3): teleports, saving, leaderboards,
      friends together
- [x] **Phase 6 boosters** (2026-10-22): the four Developer Products are on Creator Hub (+1, +3, +5, +10 floors at 15, 40, 60, 100 Robux, Managed Pricing off);
      their ids are in `src/shared/Booster.luau`
- [x] Game page (2026-10-22): description from `publish/RELEASE.md` §5, genre **Action** (locked until 2027-01)
- [x] Icon and thumbnails (2026-10-22): `publish/art/` (icon: the roof sign under crossed searchlights; thumbnails: the tower at night, a climber riding up into the gym, the open roof, the Arcade, the Nightclub), uploaded for the home page and the detail page
- [ ] Then **public for 16+** (`publish/RELEASE.md` §7): the age check on the owner's account, the maturity
      questionnaire filled in to the end (expected Mild), Access → Public
- [ ] Then **all ages** (§7): ID verification, 2-step verification, Roblox Plus / Premium for 2 months or
      the refundable 1,000 Robux fee; then Roblox's evaluation (250 unique plays from highly engaged 16+
      players within 60 days; Creator Hub → Audience Reach)
- [ ] **Getting paid** (§8): a DevEx portal account and the tax form (W-9 / W-8); cash out from 30,000
      earned Robux (≈ $114), once a month

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
6. **Robux items**: the user's call (2026-10-19): a paid booster that flies you up the shaft. *Built; the
   products are created on Creator Hub.*
7. **Publishing**: game page text, icon, thumbnails, maturity questionnaire answers (aim: Mild), release
   checklist, going public and getting paid. *Kit ready in `publish/RELEASE.md` (§7 going public, §8
   getting paid); the publishing itself is the user's.*

## Decisions (2026-10-18)

The flow
- Press Play → a **lobby** (the forecourt in front of the tower). Lobby servers hold **20**.
- A **20 s countdown** (45 s until the user's call on 2026-10-20) starts with the first player in; it drops to
  5 s when 20 are waiting. At zero, **everyone in
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
  occlusion is Roblox's "Zoom" (Invisicam faded the floor under your feet, 2026-10-18). 2026-10-19: walls
  and floors keep the camera in front of them; furniture, crates and roof props ghost instead (only on your
  screen), and your own silhouette shows through a wall that still hides you (nobody else's).
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
- **Real gun sounds and fun music** (the user, 2026-10-20: the old ones were "atrocious"): each gun is a real
  recording of a real gun (9mm Beretta pistol and SMG, .223 CAR-16 rifle, 12 gauge Mossberg pump), several
  takes each, built like a real shot is heard: the crack and body, the echo, and the gun's mechanics as their
  own sounds where they happen (pump, brass on the floor, magazine out / dropped / slapped in, slide or bolt,
  shells loaded one by one). Bullets strike walls (sometimes ricochet) and whiz past your head; far shots
  lose their top end; a full-auto burst turns its earlier shots down. Cuts and volumes were measured from the
  recordings themselves (downloaded and analysed, loudness and spectrum). Music: APM's "Gaming Drum & Bass"
  album (made for games): a five-track race playlist, "Fighting Robots" on the roof, "Game Lobby" (and its
  alternate) in the lobby, their volumes evened out by measured loudness. Uploading outside audio would need
  rights and an upload key; the licensed library covered everything.
- **Settings**: music, effects, mouse sensitivity, camera shake, damage numbers; kept with the profile.
- **The flow** (the user, 2026-10-19, like the original): opening the game shows a **main screen** (Play, How
  to play, Looks, Stats, Leaderboards, Settings) over a slow orbit of the tower. Play → the forecourt → the
  race. Lose (or nobody gets out) → a result card → Main screen. Win → explore the roof, take the skydive, or
  End game → main screen. The skydive never hits the ground: four floors up it stops, shows the rings taken,
  and goes to the main screen. Nothing restarts by itself (Studio: Play again on the card). Players who don't
  press are sent back after 90 s (the winner after 10 min). A Studio-only Win now button puts you on the roof.
- **Bigger platforms** (the user, 2026-10-19): decks half again as big, 3.5 m -> 5.25 m across; the shaft
  grows with them (one number: `DECK_HALF` in `shared/Config`).
- **Bodies that move like they're alive** (the user, 2026-10-19): a procedural layer over Roblox's own
  animations on every climber, players and bots: legs follow where you move (backing off runs in reverse),
  stances, recoil and reloads per gun, flinches by where a hit lands, landings in the knees, breathing and
  fidgets, set-piece poses (boost, skydive, knock-out, coming to, the end). All cosmetic: nothing changes
  what the server decides.
- **Phase 6: a paid booster** (the user's design; it replaces "cosmetic only" from 2026-10-18): a glowing
  pad beside the shaft on every floor (1–17); F / D-pad up / tap opens the choices: +1, +3, +5 or +10 floors,
  each a Developer Product. Bought, you fly up the shaft like Iron Man (jets from your feet) to that floor.
  Limits the user chose: never above floor 18, and closed once the roof opens at 4:00, so the end is earned.
  Every purchase becomes a saved boost credit first (counted once per purchase), then spent on the flight:
  a boost that can't happen right then waits for the next pad. Untouchable and unable to attack while
  flying; the feed says who boosted. Bots never boost.
- **Nobody walks off the roof or the plaza** (the user, 2026-10-20): the winner can't walk, jump or be
  flung off the roof (the skydive is the only way down), and players on the lobby's plaza can't leave it.
  Invisible walls in a `Barrier` collision group that only climbers bump into (`CollisionGroups.fence`),
  so the camera, shots, platforms, debris, a boost and the skydive pass through; the lobby's bodies are
  climbers too.

## Decisions (2026-10-23)

- **Teams of four** (the user's design): the 20 climbers play as five teams of four (Red, Blue, Green, Gold,
  Violet), each team starting together on its own floor (team 1 on floor 1 … team 5 on floor 5). Teammates
  can't hurt each other (swings pass them, bullets fly through them). The user's picks: **one team
  escapes** (a platform goes through the roof only with riders from a single team on it, 1–4 of them;
  riders from two teams are all thrown off, "Only one team can escape!"; that whole team wins, the ones
  still inside too: an escape on everyone's stats) and **friends together, the rest spread** (friends in
  the same race share a team, a bigger group split in fours; other players spread over the teams so they
  fight each other; bots fill the gaps). Players are on Roblox's teams too (player list, team chat). On
  screen: teammates' outlines in the team's colour through walls with their names; a colour chip over
  enemies; a team panel (each member's floor, Down / Out / Got out). Everyone who got out gets one skydive.
  Code: `shared/Teams`, the roster in `server/race/Climbers`, `client/race/Teammates`.
- **Platforms start from the bottom** (the user, 2026-10-23): the shaft is empty when the climb starts; the
  first platform leaves the bottom then, the next every 17 s behind it. Someone higher up (a team on floor
  5, a boost) waits for the first one to climb to them (floor 11: ~37 s) before the 17 s rhythm reaches
  them. Before, the shaft started full, as if platforms had been running before the race.

## Inbox

- Floors "double the size": read as 24 × 24 m (each side doubled; 4× the area). The other reading is double the
  area (~17 × 17 m). Confirm in the playtest.
- The original's own sounds (wind, the platform's clunk, the hatch grinding, confetti cannons), made with Web
  Audio: render them to files for the user to upload, if the library sounds don't fit
- More ways to earn (2026-10-24, the user's call; only the boosters are built): passes (one-time, e.g. a
  pack of looks or a cosmetic trail; nothing that wins races), paid private servers (a group's own lobby
  and race; needs code), immersive ads on the plaza's boards, subscriptions, Managed Pricing back on for
  regional prices

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
- **Going public (checked 2026-10-24):** the owner's age check + the questionnaire = public to age-checked
  16+ only. All ages (Select 9–15, Kids 5–8; Mild reaches both) also needs ID verification, 2-step
  verification, Plus / Premium 2 months or a refundable 1,000 Robux fee, and 250 unique plays from highly
  engaged 16+ players within 60 days. Details in `publish/RELEASE.md` §7.
- **Payouts (checked 2026-10-24):** 70% of each Developer Product sale; Creator Rewards (5 Robux per Active
  Spender playing 10+ min a day; 35% of new players' first $100); DevEx from 30,000 earned Robux at $0.0038,
  once a month, 13+, verified email, tax form. Details in `publish/RELEASE.md` §8.

## Done

- [x] 2026-10-23 — **No more getting stuck; small prompts** (the user's playtest): the Machine Room's hoist had a
  solid rail lower than a jump with less room inside than a body: anyone who jumped or was knocked over it
  was wedged there for good (no reset). It now has an invisible keep-out block only climbers bump into
  (`Kit` `k.keepOut`; shots and the camera pass). A scan of every floor in Studio (standing spots you can't
  get back from, sealed slots a body could drop into) found no other trap; a dummy dropped into each
  flagged slot walked out. Safety net: `shared/Unstuck` + `client/race/Unstick` (and bots in
  `server/race/Bots`): held a direction 1.5 s, got nowhere and boxed in, you're set down on the nearest
  open spot on the same floor. The pickup and booster prompts are our own small pill (`client/race/Prompts`:
  key chip + "Pick up Rifle"; tap it on touch). Not yet seen by the user

- [x] 2026-10-23 — **Polish pass** (the user's ask: bugs, speed, natural bots, a real pistol sound). Checked
  in Studio play-solo (scripts pushed by the MCP; every script then matched the repo):
  - Bots (`server/race/Bots`): steered every frame (ease up to speed, curve round, plant to reverse,
    walk when idle and stop to look round); gunfights at each gun's preferred range with burst strafing,
    reloading crouched behind cover (`Tower.covers`), hearing shots, backing up teammates, fighting only
    who they can see. Seen: the stroll / look round / stage / board / ride cycle, cover and crouch
  - Pistol: the 9mm takes rang 30 ms (measured with an AudioAnalyzer); now five .45 Grizzly takes
    (~0.6 s tail). Quiet recordings turned up (bat whoosh, thuds, knock-out fall). Not heard yet
  - Loading 10.1 s -> 7.7 s in Studio (terrain built during the download; no blocking preload of the
    tower, which has nothing to fetch). The live gain from overlapping the download isn't measured
  - Race server: players arriving before it listened / during setup / after the end are handled;
    friend checks asked as players arrive. Shots are one unreliable message; unchanged values not resent
  - `server/race/FairPlay`: no going up floors without a platform or a boost (a teleport was put back,
    a ride left alone). End card shows your climb. Full auto keeps its rate at any frame rate
  - Left: pure-logic specs for the bots' steering and the climb rule; listen to the pistol in play

- [x] 2026-10-23 — **Team mode and platforms from the bottom** (see Decisions 2026-10-23). Checked in Studio
  (scripts pushed by the MCP: Rojo wasn't connected): five teams of four on floors 1–5; at 21 s only two
  platforms in the shaft (floor 6 and just off the ground); a rifle burst through a teammate left them
  unhurt and hit the enemy behind (100 → 22); a bat swing at a teammate did nothing; Win now gave "Blue
  team got out first", the roof strip and skydive pad, and the teammates inside counted as winners; the
  team panel and teammates' outlines and name tags on the client; no errors. Not yet seen: how the
  outlines and panel look, a real roof escape by a team of bots, friends grouping (live only)

- [x] 2026-10-21 — **Every floor redesigned, BOOST UP only on your floor, one-colour walls** (the user's
  asks): the booster's label (and every floor's signs, screens, particles and beams) shows only on the
  floor you're on (`Cutaway`; it floated over the cut-away floors above). The walls' room side is one
  finish all over, round the window reveals too (the piers were bare concrete between coloured bands),
  with a skirting and its glowing line, a sill, a cornice, framed windows (transom and mullions) and a
  dark cap on the cut top. Floors get a border and a walkway finish. Each theme now has a plan (furniture
  placed by design: cars in painted bays, racking along walls, desk pods, rack rows facing over their
  aisles, a boxing ring, a dance floor under a lighting rig...) and dressing (signs, neon, paintings with
  lamps, sconces, pipes, cable trays, mirrors, hatched zones, floor patterns, splats), and ~110 new
  detailed pieces (`Kit` builder and SurfaceGui art, `Pieces`, `Props*`). Checked in Studio: built in
  0.64 s, 10.8 k tower parts (was 3.4 k), no errors, no part through a wall, floor or ceiling or on the
  walkway, every planned piece placed. To pay for it the client doesn't draw furniture and dressing on
  floors two or more below you (LocalTransparencyModifier, as the cut floors: 60 fps in play-solo); the
  lobby builds the floors' shells only (`Tower.build({ interiors = false })`).
- [x] 2026-10-20 — **Fenced roof and plaza, a 20 s lobby countdown** (the user's asks): an invisible fence
  on the roof parapet's inner face, from the roof up 60 studs (the floors below don't have it), and round
  the lobby plaza's kerbs and across the walkway (see Decisions). Checked in a Studio playtest of the race:
  walking and jumping at every side and a corner, and a 120 studs/s fling, all stop at the parapet (with
  the fence switched off, a jump clears the parapet in 1.3 s); camera-style, plain and bullet casts pass
  through; the skydive pad still launches (0.4 s) and flies out over the valley. `Config.LOBBY_COUNTDOWN`
  45 → 20. The plaza's fence isn't checked in Studio yet (same code as the roof's; try it in the lobby).
- [x] 2026-10-20 — **Out once the roof is open, one wall cut, a real boost pad** (the user's playtest asks;
  checked in a Studio playtest): a knock-out after the roof opens is final: bots are removed, a player is
  marked Out and watches the climbers still in (`client/race/Spectate`: Prev / Next, ← / →, L1 / R1; Main
  screen, or Play again in Studio); nobody left in ends the race with no winner. The outer wall on the
  camera's side of you (or of whoever you watch) is cut away, one wall only, and the camera stays out past
  it (`Cutaway`; `Tower` tags each wall piece with its Side). The boost pad's flat arrow read as clock hands:
  now an inner ring, a column of light, rising sparks and a BOOST UP label. Also: crosshair on the shot's
  line, your own gun held where your camera sees it, the skydive pad launches reliably. Studio hook
  `RooftopDev:Invoke("ko", who)`.
- [x] 2026-10-20 — **Cover, crouching, fairer bots, one health bar** (the user's playtest asks; written,
  waiting on the user's own playtest): C / Left Ctrl / R3 / a touch Crouch button crouches (again or jump to
  stand): the server lowers the body by `Config.CROUCH_DROP` of its hip height (the hitbox too), half speed,
  no jumping, and no shooting till you stand (refused on the server; a "Stand up to shoot" hint, dimmed
  crosshair); every screen folds the knees (`client/race/Poser`). Furniture with bulk stops bullets
  (`Themes` "cover" pieces: sofa backs and arms, mattresses, car cabins, foliage...; desks and pool tables got
  solid fronts so shots don't go under). Bots react before their first shot, miss by a skill-based error that
  settles as they keep firing, shoot where a moving target was (`Combat.botAimError` / `botLag`, specced),
  and never fire without a clear line to the body. Roblox's own top-right health bar is off; ours goes green
  to yellow to red. Studio: T wins now (the Win now button is gone).
- [x] 2026-10-20 — Audio overhaul (`shared/Sounds`, `client/common/Audio`, with a Lune spec): real gunshots,
  per-gun mechanics and reloads timed to the hands (`client/race/Poser`), impacts, ricochets, whizzes,
  casings, body / bat / blocked hits, knock-out body falls, new beeps and clicks; race, roof and lobby music.
  Checked in a Studio playtest: all 64 ids load, each gun's shot / pump / casing / reload plays in order, a
  burst ducks its earlier shots, a shot 200 studs off is filtered
- [x] 2026-10-19 — A full read of the code and the fixes it found: bullets lifted their target (full auto
  kept it floating); a held guard dropped for good after a swing; the crosshair never changed size; ammo
  boxes from one race respawned into the next and full climbers used them up; drops hung in the shaft;
  unsaved settings were undone by other saves; the winner was told apart by display name (not unique);
  casings and confetti bumped climbers; the skydive reported twice; LoadCharacter (deprecated) in the lobby;
  far climbers' poses could compound when Roblox throttled their animation
- [x] 2026-10-19 — Platforms 1.5x (5.25 m decks), the shaft and everything sized from it following; the
  roof's helipad moved clear of the hatch; furniture kept off booster pads
- [x] 2026-10-19 — The camera: a sphere-cast instead of a ray (no clipping into walls and corners), in at
  once and smoothly back out; ghosted props (`client/race/Sightline`); your silhouette through walls
- [x] 2026-10-19 — The movement overhaul (`client/race/Poser`, `Gunwork`, `shared/Motion` with tests; bots'
  run keeps pace and reverses on the server). The gun stances were tuned with the real arm solver run in
  Lune on R15 arm lengths: both hands land exactly; the other hand sits 0.8+ studs along the rifle and
  shotgun, 0.4+ on the SMG
- [x] 2026-10-19 — Valley mountains written as voxels (`Valley.tiles` / `Valley.voxels`, `WriteVoxels`) instead
  of 126 big `FillBall`s and the replace sweeps: the same voxels from the floor up (all 21.9 M compared in
  Studio against the old build, occupancy within 1/255), nothing built below y = −20 (under the floor).
  Measured in Studio (wall clock, real LocalScript, camera in the sky, then the race's first views): build
  4.8–7.2 s → 2.9–4.0 s, build + views 8.1–12.7 s → 6.3–8.6 s; terrain cells 43.4 M → 19.1 M
- [x] 2026-10-19 — Performance pass (measured in Studio, wall clock): loading the race 21.4 s → 14.9 s, the
  lobby 18.2 s → ~11 s (terrain sweeps only where their material can be, few frames during the build, the
  lobby warms its own views, preloads alongside the build, sounds preloaded, our screen on teleports); the
  cut-away's tick 3.5 ms → 0.03 ms; one window pane a wall (640 → 80 see-through parts); the arm solver
  in closed form; booster prices fetched up front; bot rigs built in parallel
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
- [x] 2026-10-19 — The main screen in the lobby place, the end-of-race choices (no automatic restart), the
  skydive stopping above the ground with its ring count, the Studio Win now button (see Decisions: the flow)
- [x] 2026-10-19 — Lighting (the user's report: rooms blinding, the outside too dark, rooms dark for a couple
  of seconds at the start). Found in Studio: the place ran the Soft lighting style; the four 1.8-bright lamps
  per floor washed rooms out to white; Roblox rebuilds lighting round the camera after a big move (~2.5 s
  after the intro, ~4 s after the roof shot from a low floor). Now: Realistic style set by the game, light
  mostly in Ambient (rooms are under open sky once cut away, and Roblox is slow to notice), lamps 0.45 as
  accents, bloom only on neon, brighter ground colours and horizon, a "FLOOR 3 · WAREHOUSE" card over the
  end of the intro and a "THE ROOF IS OPEN" card after the roof shot (get-ready 10 s, roof scene 5.8 s),
  Camera.Focus kept on the player during set pieces (added last, not checked in Studio), bare ground under
  the concrete. Checked in Studio: the start fades onto a lit room; the warehouse floor is warm, not white
- [x] 2026-10-19 — The winner's skydive (the original's): a pad on the roof by the sign for a player who wins;
  it flings them out over the valley to glide through 12 rings (W dives, S flares, A / D or the stick steer),
  each ring lifts them; the celebration lasts until they land (40 s at most); the feed counts the rings.
  Checked in Studio: launch, the arc, the glide over the valley, the rings, landing far down the valley
- [x] 2026-10-19 — Controller in the menus: a panel opened with a controller starts on its first control, B
  closes it, sliders move with D-pad left / right; the race HUD in the ink-and-chalk look
- [x] 2026-10-19 — Phase 6: the paid booster (see Decisions), checked in Studio: pads on floors 1–17, F opens
  the choices, +5 flew floor 4 → 9 up the shaft, +10 greyed out past floor 18, the feed line, no errors
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
