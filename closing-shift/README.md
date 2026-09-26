# CLOSING SHIFT

You and up to 3 friends work the last shift at a 24-hour convenience store, in first person, with a PSX look. Mop every spill before 6:00 AM. The store gets wrong as the night goes on. The last spill is in the back room.

The experience has two places:

| Place | ID | Project | What happens there |
|---|---|---|---|
| **Lobby** (start place) | 104809971812455 | `lobby.project.json` | Everyone spawns in the Quik Stop parking lot: queue pads, parties, leaderboards, wardrobe (cosmetics), shop, upgrade lockers, job board, daily time clock, VIP lounge. Queues teleport each crew to its own private Shift server. |
| **Shift** | 93047688567585 | `default.project.json` | The game itself: the store, the nights, the Manager. BACK TO LOBBY returns you. |

Both are Rojo projects built from Parts in code, so no `.rbxl` file is committed. They share `src/shared`
and the server modules the lobby lists in `lobby.project.json` (save data, economy, shop, cosmetics,
jobs, name tags, leaderboards). The place IDs are in `Config.Places`.

## Getting it into Studio

1. Install [Rojo](https://rojo.space) (the CLI and the Studio plugin).
2. Open the place you want to work on (Asset Manager > Places in Experience). From this folder run
   `rojo serve` for the Shift place or `rojo serve lobby.project.json` for the Lobby, then click
   **Connect** in the Rojo plugin.
3. Press Play. The Shift server builds `Workspace.Store` and the Lobby server builds `Workspace.Lobby`
   if they don't exist.
4. Optional: to edit the map in edit mode, run this once in the command bar and save the place:
   ```lua
   require(game.ServerScriptService.Server.StoreBuilder).Build() -- Shift place
   require(game.ServerScriptService.Server.LobbyBuilder).Build() -- Lobby place
   ```

Teleports don't run in Studio: a queue countdown in a Studio playtest ends with a notice instead.
Playing the Shift place directly (not from a queue) uses its own in-store lobby, which is handy for testing.

## Publishing settings

In Creator Hub (or Studio: Game Settings), set these:

- **Max Players: Lobby 24, Shift 4.** The nights are tuned for a crew of 1 to 4 sharing one set of
  spills, and the Manager gets 15% faster for each extra player (`Config.Manager.SpeedPerExtraPlayer`).
  Queues never send more than `Config.Queue.MaxCrew` (4).
- **API Services on** (Security), so DataStores save progress, cash and purchases.
- Publish the **Shift place first**, then the Lobby, so a queue never sends players to an old version.
- Passes, developer products and badges already exist and their IDs are in
  `src/shared/Data/Monetization.lua`. An ID of 0 hides that item in game.

## Progression and economy

- **Cash** comes from paychecks, the daily clock-in and jobs; it buys upgrades (lockers) and
  cosmetics (wardrobe: `src/shared/Data/Cosmetics.lua`, some VIP-only). Everything is a direct
  purchase; there are no random rewards.
- **Jobs** (`src/shared/Data/Challenges.lua`): 3 daily and 2 weekly, the same for everyone, paid on completion.
- **Ranks** come from lifetime spills cleaned (`Config.Ranks`); promotions are announced.
- **Leaderboards**: Employee of the Week (spills you mopped yourself this week; top 3 get a trophy
  tag), fastest shift per night (only runs with no Robux help), lifetime earnings (pay before VIP /
  Starter Pack multipliers) and most spills ever.
- **Parties**: invite players in the lobby; when the leader stands on a pad the party queues together.

## Where things live

| Studio location | Source | What it does |
|---|---|---|
| `ReplicatedStorage.Shared.Config` | `src/shared/Config.lua` | Global tunables (clean timing, sprint, flashlight, PSX look, sounds). Pulls in the Data tables. |
| `ReplicatedStorage.Shared.Data.*` | `src/shared/Data/*.lua` | Content as data: `Nights`, `Events`, `Modifiers`, `Stores`, `Upgrades`, `Monetization` |
| `ReplicatedStorage.Shared.Rules` | `src/shared/Rules.lua` | Resolves a night + modifiers into the numbers a shift runs on (server and clients) |
| `ReplicatedStorage.Shared.Clock` | `src/shared/Clock.lua` | Maps shift seconds to the 2:00–6:00 AM clock |
| `ReplicatedStorage.Remotes` | `default.project.json` | Every RemoteEvent (the server also creates any that are missing). Client to server: `ReadyUp`, `PickNight`, `RequestCoffee`, `BuyUpgrade`, `RequestPurchase`, `Flashlight`, `ViewReport` (unreliable). All are validated and rate-limited on the server; the client never sends cash. |
| `ServerScriptService.Server` | `src/server/init.server.lua` | Entry point and Studio-only `_G.ClosingShift` test commands |
| `…Server.StoreBuilder` | `src/server/StoreBuilder.lua` | Store layout, props, materials, PSX lighting |
| `…Server.RoundManager` | `src/server/RoundManager.lua` | Lobby → Shift → Payoff or Lights out → Results, driven by the night's rules |
| `…Server.SpillService` | `src/server/SpillService.lua` | Spawns spills, server-validated cleaning, the final back-room spill |
| `…Server.EventDirector` | `src/server/EventDirector.lua` | Runs the night's events and power cuts |
| `…Server.Events.*` | `src/server/Events/*.lua` | One module per "wrong" event, registered by file name |
| `…Server.Payoff` | `src/server/Payoff.lua` | Back-room reveal and the note prompt |
| `…Server.DataService` | `src/server/DataService.lua` | Versioned player profile (cash, unlocks, per-night bests, stats, upgrades, coffees, daily streak, receipts), merge-saved with UpdateAsync |
| `…Server.Economy` | `src/server/Economy.lua` | Paycheck, daily bonus, locker upgrades; all cash goes through `AddCash` / `SpendCash` |
| `…Server.Manager` | `src/server/Manager.lua` | The Night Manager: moves when nobody is looking, catches players |
| `…Server.ServerBoosts` | `src/server/ServerBoosts.lua` | Server-wide paid boosts (Lights On, Janitor, Spill Storm, Manager Day Off) with a cooldown |
| `…Server.ShiftBoard` | `src/server/ShiftBoard.lua` | The board in the break room where the party picks a night |
| `…Server.Analytics` | `src/server/Analytics.lua` | AnalyticsService: onboarding funnel, economy events, custom events |
| `…Server.Leaderboard` | `src/server/Leaderboard.lua` | OrderedDataStore top 10, drawn on the board by the counter |
| `…Server.Badges` / `Monetization` / `Mop` | `src/server/*.lua` | Badge awards; passes, products, gifts and receipts; the Mop tool |
| `StarterPlayerScripts.Client` | `src/client/init.client.lua` | Starts the client modules below |
| `…Client.Controls` / `Movement` | `src/client/*.lua` | Keyboard/gamepad/touch bindings; sprint + stamina (owns WalkSpeed) |
| `…Client.CameraFx` / `Overlay` | `src/client/*.lua` | FOV, head-bob, camera snap; scanlines, pixel grid, vignette, flicker |
| `…Client.Viewmodel` / `Flashlight` | `src/client/*.lua` | First-person mop; flashlight with battery |
| `…Client.SoundFx` / `Juice` | `src/client/*.lua` | Ambient sound bed and stings; clean feedback (particles, +1, ka-ching) |
| `…Client.Hud` / `Prompts` / `LightsFx` / `PayoffFx` | `src/client/*.lua` | HUD and results, prompt gating + touch MOP button, light flicker, payoff camera |
| `…Client.Shop` / `Offers` / `Locker` | `src/client/*.lua` | Vending-machine shop; Second Chance, Clock In Late and Starter Pack offers; upgrade locker |
| `…Client.NightPicker` / `Tutorial` / `ManagerView` / `CatchFx` | `src/client/*.lua` | Shift-board picker, first-night hints, camera view reports, the catch screen |

## Adding content

Everything a shift runs on comes from the Data tables, so most additions are data, not code.

### A night

Append a table to `src/shared/Data/Nights.lua`. Every field is documented at the top of that file:
`Name`, `SpillCount`, `ShiftLength`, `Events` (names of event modules), `EventGap`, `Manager`
(`Enabled`, `Speed`), `PowerCuts` (`Enabled`, `Every`, `Duration`), `Store`, `Tutorial`, `Tease`.
The night's number is its position in the list. Test it with `_G.ClosingShift.Night(4)` then
`_G.ClosingShift.Start()`.

### An event

1. Add `src/server/Events/MyEvent.lua` returning `function(ctx) ... end`. The file name is the event name.
2. Add tuning for it in `src/shared/Data/Events.lua` (`Weight`, `UsesSpills`, plus anything your module
   reads from `ctx.tuning`).
3. List `"MyEvent"` in the `Events` of the nights that should have it.

`ctx` gives you: `store`, `props` (a folder cleared between shifts), `rng`, `tuning`, `spills` (SpillService),
`builder` (StoreBuilder), `isCurrent()` (false once the shift has ended; check it after any wait),
`aisles()`, `roots()` (players' HumanoidRootParts), `setSignNumbers`, `playSound`, and `cutPower()`
(turns the power off and returns a function that releases it; overlapping cuts are handled for you).
Test it with `_G.ClosingShift.Event("MyEvent")`.

### A modifier

Add a table to `src/shared/Data/Modifiers.lua` using the fields listed there
(`SpillCountMult`, `ShiftLengthMult`, `EventGapMult`, `ManagerSpeedMult`, `WalkSpeedMult`, `PowerCuts`).
`Shared/Rules.lua` applies them. If you add a new kind of field, apply it in `Rules.Resolve`.

### A store

1. Write a builder module in `src/server/` with `Build() -> Model` and `SetupLighting()`, like `StoreBuilder`.
   The rest of the game finds things by name and tag, so keep the names listed at the top of `StoreBuilder.lua`
   (`SpawnPoint`, `SpillMarkers`, `FinalSpillMarker`, `Aisles`, `Lights`, `Spills`, `EventProps`, …).
2. Register it in `src/shared/Data/Stores.lua` and point a night's `Store` at it.

Only one store exists at a time; `Config.DefaultStore` is the one the server builds.

## Playtest commands (Studio only)

While playing, switch the command bar to **Server** and run:

```lua
_G.ClosingShift.Night(2)             -- play night 2 next
_G.ClosingShift.Start()              -- skip the intermission
_G.ClosingShift.CleanAll()           -- clean every spill (tests the win, payoff and results flow)
_G.ClosingShift.CleanOne()
_G.ClosingShift.Timeout()            -- end the shift now (tests the lose flow)
_G.ClosingShift.Event("Mannequin")   -- SignGlitch, Footprints, DoorChime, IdenticalAisle, LightsOut, Mannequin
_G.ClosingShift.ManagerDebug()       -- where the Manager is and who is watching it
```

Set the workspace attribute `AnalyticsDebug` to true to print every analytics event while playing.

Purchases: in Studio, Roblox shows a test purchase sheet (no Robux are charged) and the game grants
the product as it would live.

## Sounds

Sound effects come from Pro Sound Effects and APM (licensed for every Roblox experience) plus a few free
Creator Store uploads; all were checked to load. The IDs and what each is for are in `Config.Sounds`.

## Linting

`selene src` checks the code with the minimal Roblox std stub in `rbx.yml`. It catches syntax errors and common Lua mistakes, but it is not a Luau type checker. Studio's Script Analysis window is where `--!strict` type errors show up.
