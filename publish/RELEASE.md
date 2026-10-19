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
   new place** named **Rooftop Race** (the name must contain "Race": until step 3 the servers find the
   race place by name).
3. Creator Hub → Rooftop → **Places**: copy both place ids into `src/shared/Places.luau` (`LOBBY`, `RACE`),
   commit, rebuild both places and publish each again (File → Publish to Roblox).
4. Creator Hub → Rooftop → **Configure**:
   - **Places**: Lobby and Rooftop Race: max players **20**.
   - **Avatar**: avatar type **R15** (the arms are posed for R15 rigs).
   - **Security**: optionally *Enable Studio Access to API Services*, to test saving in Studio.
   - **Devices**: Computer, Phone, Tablet, Console.
   - **Access**: keep it **private** until the release test below passes.
   - **Audio**: every sound is from Roblox's own licensed library or ships with Roblox: nothing to upload.
5. **Boosts for Robux** (phase 6): Creator Hub → Rooftop → Monetization → **Developer Products**: create
   four, one per size, e.g. *Boost +1 floor*, *Boost +3 floors*, *Boost +5 floors*, *Boost +10 floors*,
   and set their prices (a starting point: 15, 40, 60 and 100 Robux). Put their ids in
   `src/shared/Booster.luau` (`PRODUCTS`), commit, rebuild and publish the race place again. While an id
   is 0 that size isn't for sale (in Studio the pads give free test boosts instead). Studio's purchases of
   real products are test purchases: nothing is charged.

## 3. Release test (in the published, private game)

Teleports and data stores only work there. With 2–4 accounts (or friends) on different devices:

- [ ] You arrive on the lobby plaza; the countdown starts; the board over the walkway counts too
- [ ] At zero everyone goes together into one race (bots fill to 20); the intro plays
- [ ] A friend who joins you from the friends list lands in your lobby and goes in the same race
- [ ] Guns: pistol, rifle and SMG (hold to fire), shotgun; pickups, ammo, reload; melee and guard
- [ ] Touch: Fire / Aim / Reload / Swap buttons; controller: R2 / L2 / X / Y / B / View
- [ ] The roof opens at 4:00 (or skip ahead in Studio first); one alone through the roof wins
- [ ] A player who wins gets the skydive pad by the roof sign: the glide through the rings works with keys,
      a stick and a phone's thumbpad; the celebration waits until they land
- [ ] After the celebration everyone is sent back to the lobby
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

## 5. Game page

**Name:** Rooftop

**Description:**

> Twenty climbers. One tower. Only one can escape.
>
> Race up a 20-floor tower at night, riding the platforms that rise up the shaft. Fight your way past
> everyone else with a bat, a sword or a pistol, or grab the rifles, SMGs and shotguns that turn up on
> the platforms. Knocked out? You come to a few floors lower. Keep climbing.
>
> At 4:00 the roof opens. The first climber to ride a platform up through the roof ALONE wins. Two on the
> platform and it throws you both off.
>
> • Races of 20: friends who join you race with you, bots fill the rest
> • Booster pads fly you up the shaft (up to floor 18, until the roof opens)
> • Unlock 10 climber looks by playing
> • Leaderboards: most escapes, most knock-outs, fastest escape
> • Play on computer, phone, tablet or console

**Genre:** Fighting (or Obby & Platformer). **Max players:** 20.

## 6. Icon and thumbnails

Take them in Studio with the place playing (a big viewport, the HUD hidden by the set pieces):

- **Icon (512 × 512):** the lit tower at night with the glowing ROOFTOP title on the hill behind it
  (the intro's first shot), cropped square.
- **Thumbnails (1920 × 1080), 3–5:** the tower from the valley at night (the intro); a fight on a platform
  in the shaft, muzzle flashes lighting the room; the roof opening, searchlights sweeping; the winner
  rising through the roof with fireworks; the lobby plaza with the countdown board.

No real gun brand names, no blood, no text that promises anything the game doesn't have.

## 7. Going public

When the release test passes: Creator Hub → Rooftop → Access → **Public**. Bump `src/shared/Version.luau`
for every release after that (it shows in the lobby's corner).
