# Releasing Rooftop

Everything here that happens on Roblox's site (publishing, settings, the questionnaire, making the game
public) is done by the owner, on their personal account. The code side is ready: both places build from
this repo.

## 1. Build both places

```
rojo build lobby.project.json -o build/lobby.rbxl
rojo build race.project.json -o build/race.rbxl
```

The lighting (LightingStyle = Realistic) comes from the project files and the game itself: nothing to set
by hand. The Workspace attributes `LookPreset` and `TestBots` only work in Studio and can stay or go.

## 2. Publish (private)

1. Open `build/lobby.rbxl` in Studio → File → **Publish to Roblox As…** → a new experience named
   **Rooftop**, owned by your personal account. This place is the **start place** (the lobby).
2. Open `build/race.rbxl` → File → **Publish to Roblox As…** → pick the Rooftop experience → **add it as a
   new place**. Studio creates it at once with an automatic name ("…'s Place: …"); rename it to **Rooftop
   Race** on Creator Hub → the place → Basic Settings (until step 3 the servers find the race place by a
   name containing "Race").
3. Creator Hub → Rooftop → **Places**: copy both place ids into `src/shared/Places.luau` (`LOBBY`, `RACE`),
   commit, rebuild both places and publish each again (File → Publish to Roblox).
4. Settings (Studio's old *Game Settings* is now **File → Experience Settings**):
   - **Max players 20**: Creator Hub → Rooftop → Places → each place → **Access** → *Maximum Visitor
     Count* `20` → Save.
   - **Avatar R15**: Studio → **File → Avatar Settings** → **⋯** (top right) → **R15 Only** (the arms are
     posed for R15 rigs; new experiences already default to it).
   - **Security**: File → Experience Settings → Security → *Enable Studio Access to API Services*, to test
     saving in Studio.
   - **Devices**: Computer, Phone, Tablet, Console.
   - **Access**: keep it **private** until the release test below passes.
   - **Audio**: every sound is from Roblox's own licensed library or ships with Roblox: nothing to upload.
5. **Boosts for Robux** (phase 6): Creator Hub → Rooftop → Monetization → **Developer Products**: create
   four, one per size, e.g. *Boost +1 floor*, *Boost +3 floors*, *Boost +5 floors*, *Boost +10 floors*,
   and set their prices (a starting point: 15, 40, 60 and 100 Robux). Put their ids in
   `src/shared/Booster.luau` (`PRODUCTS`), commit, rebuild and publish the race place again. While an id
   is 0 that size isn't for sale (in Studio the pads give free test boosts instead). Studio's purchases of
   real products are test purchases: nothing is charged.

## Publishing from the terminal (every update)

The game is published: experience **Rooftop** (universe 10771906434), lobby place 96194017293551 (the start
place), race place 127585457284186 (**Rooftop Race**). Updates go out with one command, no Studio:

```
powershell -ExecutionPolicy Bypass -File publish\publish.ps1              # both places
powershell -ExecutionPolicy Bypass -File publish\publish.ps1 -Place race  # only one
```

It runs the tests, lint and format check, then builds each place (`rojo build`) and uploads it to Open
Cloud's place publishing as a new **published** version (from PowerShell, not `rojo upload`: Avast's HTTPS
scanning makes rojo fail with "invalid peer certificate: UnknownIssuer"; Windows trusts Avast's root). New servers run it; running ones keep the old version until they empty (in a private
game: leave and rejoin). Publish both places whenever `src/shared` or a `common` folder changed: they share
that code. Bump `src/shared/Version.luau` for a release so the lobby corner shows which one you're in.

The upload replaces the whole place with what this repo builds. Anything changed only in Studio is gone
from the new version, and a Studio window still open on a published place (Team Create) holds the old copy:
don't press Publish there afterwards; reopen it from Roblox instead.

**The key, once.** An Open Cloud API key lives in the Windows user variable `ROBLOX_PUBLISH_KEY`, nowhere
else (never in this repo, a file, chat or a command line you type):

1. create.roblox.com → **Creator Hub** → **Open Cloud → API Keys** (create.roblox.com/dashboard/credentials)
   → **Create API Key**.
2. Name: `Rooftop publish`.
3. **Access Permissions** → Select API System: **universe-places** → Add API → Restrict by Experience:
   **Rooftop** → Select Operations: **Write**.
4. Security: leave *Restrict IP addresses* off (or add your own IP). Expiration: none, or a date to renew it.
5. **Save & Generate key** → **Copy Key to Clipboard** (it's shown once).
6. Windows: Start → type *environment* → **Edit environment variables for your account** → under *User
   variables* → **New…** → Name `ROBLOX_PUBLISH_KEY`, Value: paste → OK, OK.

The script reads the variable straight from your account, so it works at once; other programs see it after
they restart. A key that leaks: delete it on the API Keys page and make a new one.

## 3. Release test (in the published, private game)

Teleports and data stores only work there. With 2–4 accounts (or friends) on different devices:

- [ ] Opening the game shows the main screen (Play, How to play, Looks, Stats, Leaderboards, Settings)
- [ ] Play puts you on the lobby plaza; the countdown starts; the board over the walkway counts too;
      Main screen takes you back
- [ ] At zero everyone goes together into one race (bots fill to 20); the intro plays
- [ ] A friend who joins you from the friends list lands in your lobby and goes in the same race
- [ ] Guns: pistol, rifle and SMG (hold to fire), shotgun; pickups, ammo, reload; melee and guard
- [ ] Touch: Fire / Aim / Reload / Swap buttons; controller: R2 / L2 / X / Y / B / View
- [ ] Teams: five teams of four, each starting on its own floor (1–5); friends in the same race share a
      team; teammates glow through walls, can't hurt each other; the team panel shows their floors
- [ ] The first platform starts from the bottom when the climb starts; nobody higher up gets one until it
      climbs to them
- [ ] The roof opens at 4:00 (or skip ahead in Studio first); a platform with only one team on it takes
      them through the roof and that team wins; riders from two teams are thrown off
- [ ] Players who got out get the skydive pad by the roof sign (one flight each): the glide through the
      rings works with keys, a stick and a phone's thumbpad; the celebration waits until they land
- [ ] Losing shows a result card; Main screen takes you back to the main screen (or after 90 s); the
      winner's End game (G) and the end of the skydive do too
- [ ] Back in the lobby: Stats show the race, Escapes / KOs in the player list, leaderboards fill in
      (they refresh every minute), a look unlocked by the race can be worn
- [ ] Settings (music, effects, sensitivity, shake, numbers) are kept after rejoining
- [ ] Boosters: F / D-pad up / tap on a pad opens the choices with prices; buying one flies you up; a
      size past floor 18 is greyed out; after the roof opens they're closed; a purchase made just as the
      roof opens becomes a credit (Stats in the lobby shows it) and works on the next race's pads
- [ ] Leave mid-race: the race goes on with one climber fewer; rejoin lands you in the lobby
- [ ] No errors in the Developer Console (F9) on the lobby server and a race server

## 4. Maturity & Compliance questionnaire

Creator Hub → Rooftop → Audience → Maturity & Compliance. Answer from the game as it is; as of this
release:

| Question | Answer |
| --- | --- |
| Violence | Yes: **mild**, **repeated** (bats, swords and guns knock climbers out; unrealistic, no injuries) |
| Blood | **No** (hits show sparks and stars; knocked-out climbers fade away) |
| Fear | No |
| Crude humor | No |
| Unplayable gambling content | No |
| Strong language | No (only Roblox's own filtered chat) |
| Romantic themes | No |
| Alcohol | No |
| Social hangout | No (the main activity is the race; the lobby is a short wait) |
| Free-form user creation | No |
| Sensitive issues | No |
| Paid random items / paid item trading | No (boosts are sold, but they're not random and can't be traded) |
| Media | No |
| AI interaction | No |

Expected label: **Mild** (repeated mild violence). If realistic-looking violence is ever added it becomes
Moderate.

Fill it in to the end (checked 2026-10-24): the first question (age-restricted content) answered **No**
gives the game a *Content May Vary* rating, released only to age-checked users 16+; **Yes** leads to the
full questionnaire. Minimal and Mild reach every account, Roblox Kids (5–8) too; Moderate reaches 9+.
Social hangout, Sensitive issues or Free-form user creation make a game 16+, whatever else it is.

## 5. Game page

**Name:** Rooftop

**Description:**

> Five teams. One tower. Only one team can escape.
>
> Climb a 20-floor tower at night in a team of four. Ride the platforms up the shaft and fight the other
> teams floor by floor: bats and swords up close, pistols, rifles, SMGs and shotguns found on the way.
> Crouch behind sofas, desks and cars for cover. Knocked out? You come to a few floors lower. Keep
> climbing.
>
> At 4:00 the roof opens. The first team to ride a platform through the roof wins, but only if nobody from
> another team is on it: mixed platforms throw everyone off. Whoever gets out skydives off the roof
> through the rings.
>
> • 20 per race in five teams of four: friends who join you are on your team, bots fill the rest
> • Teammates glow through walls
> • 20 themed floors, from the Gym to the Arcade and the Nightclub
> • Booster pads fly you up the shaft (up to floor 18, until the roof opens)
> • Unlock 10 climber looks by playing
> • Leaderboards: most escapes, most knock-outs, fastest escape
> • Play on computer, phone, tablet or console

On Creator Hub since 2026-10-24 (994 of the 1,000 characters Roblox allows).

**Genre:** Action (set 2026-10-22; Roblox allows a change every 3 months). **Max players:** 20.

## 6. Icon and thumbnails

Take them in Studio with the place playing (a big viewport, the HUD hidden by the set pieces):

- **Icon (512 × 512):** the lit tower at night with the glowing ROOFTOP title on the hill behind it
  (the intro's first shot), cropped square.
- **Thumbnails (1920 × 1080), 3–5:** the tower from the valley at night (the intro); a fight on a platform
  in the shaft, muzzle flashes lighting the room; the roof opening, searchlights sweeping; the winner
  rising through the roof with fireworks; the lobby plaza with the countdown board.

No real gun brand names, no blood, no text that promises anything the game doesn't have.

**Uploaded 2026-10-22** (files in `publish/art/`): the icon is the roof's ROOFTOP sign under crossed
searchlights; the thumbnails are the tower at night from the valley, a climber riding the platform up into
the gym, the open roof under the searchlights, and two floors seen from above (the Arcade, and the Nightclub
with a fight at the shaft), on both the Home Page and the Experience Detail Page
tabs. How they were shot: a playtest with a client-side camera rig (scriptable camera, HUD and prompts off,
the cut-away floors shown again), Studio's panels closed for a wide viewport, the screen grabbed at full
resolution and cropped to 16:9.

**Replaced 2026-10-24** for the teams (the gym, Arcade and Nightclub shots showed no teams or fights).
Both tabs now show, in order: `thumb2-fight` (a Green team firing across the Nightclub, tracers and
muzzle flashes, teammates outlined and named), `thumb5-cover` (Gold fighting round an arcade cabinet),
`thumb4-ride` (three armed climbers riding a platform into the Arcade, enemies waiting at the boost pad),
then the tower and the roof. Shot in a Studio playtest: bots of two teams placed facing each other on a
floor, the camera fixed by a client-side rig with the HUD hidden, and a burst of frames grabbed to catch
the shots firing. Still worth adding: the lobby plaza; the skydive came out too dark to use.

## 7. Going public

When the release test passes: Creator Hub → Rooftop → Access → **Public**. Bump `src/shared/Version.luau`
for every release after that (it shows in the lobby's corner).

Who gets to see it depends on what the owner's account has done (Roblox's rules since 2026, checked
2026-10-24 on create.roblox.com/docs → *Publish experiences* and *Roblox Kids and Select*; Public and
Limited access ask for the same):

**16+ only** (age-checked Roblox users 16 and older):

- the owner's account has passed an **age check**, is in good standing and is at least 2 days old;
- the Maturity & Compliance questionnaire is done (§4).

**All ages** (adds Roblox Select, ages 9–15, and Roblox Kids, 5–8), all of the above and:

- **ID verification** (a government ID at 18 or older, a face age estimate under 18);
- **2-step verification** on;
- a Minimal, Mild or Moderate rating (Mild here);
- **Roblox Plus or Premium for 2 months in a row**, or a one-time **refundable fee of 1,000 Robux** for
  the experience (the two docs pages word the refund differently; read the terms when paying; no refund if
  the game is taken down for breaking the Community Standards);
- Roblox's **evaluation**: the game starts with 16+ players only; it becomes eligible for Kids and Select
  after **250 unique plays from highly engaged players** (age-checked 16+, by account age, play time and
  having bought something anywhere on Roblox in the last 60 days) **within 60 days**, plus a safety review
  of reports and gameplay. Progress: Creator Hub → **Audience Reach**. An expedited review costs a
  refundable 50,000 Robux.

At most 5 never-public experiences can be made public per day (not a concern with one).

## 8. Getting paid

Checked 2026-10-24 (create.roblox.com/docs → *Developer Exchange*, *Creator Rewards*, *Monetize your
games*). Robux earned go to the owner's personal account.

- **Boosters** (§2.5): the owner gets 70% of each sale: about 10, 28, 42 and 70 Robux from the 15, 40, 60
  and 100 Robux boosts.
- **Creator Rewards**, no sign-up:
  - *Daily Engagement*: 5 Robux for each Active Spender (spent $9.99+ on Roblox in the last 60 days) who
    plays Rooftop 10+ minutes that day, when it's one of the first three experiences they open that day.
  - *Audience Expansion*: 35% of the first $100 of purchases a new player (or one back after 60+ days
    away) makes in their first 60 days, if they play Rooftop 10+ minutes that day. Needs an ID-verified
    owner, the DevEx terms, and an average of 100+ daily players for those 60 days. Eligibility shows on
    the Creator Dashboard.
- **Cashing out: Developer Exchange (DevEx)**: 13 or older, a verified email, **30,000 earned Robux** at
  least, a DevEx portal account and a tax form on file (W-9 in the US, W-8 elsewhere). Once per calendar
  month, at **$0.0038 per Robux** (30,000 ≈ $114; Robux from US players verified 18+ can get $0.0054).
  Sales can take up to 24 hours to show in the earned balance.

For scale: 30,000 Robux is about 1,070 of the 40-Robux boost, or 100 Active Spenders playing every day
for two months. Other ways to earn are listed in `TODO.md` → Inbox (each is the owner's call).
