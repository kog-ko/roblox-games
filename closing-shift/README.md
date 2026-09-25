# CLOSING SHIFT

You and up to 3 friends work the last shift at a 24-hour convenience store, in first person, with a PSX look. Mop every spill before 6:00 AM. The store gets wrong as the night goes on. The last spill is in the back room.

It's a Rojo project. The whole store is built from Parts in code, so no `.rbxl` file is committed.

## Getting it into Studio

1. Install [Rojo](https://rojo.space) (the CLI and the Studio plugin).
2. From this folder, run `rojo serve`. In Studio, open the Rojo plugin and click **Connect**.
3. Press Play. The server builds `Workspace.Store` if it doesn't exist.
4. Optional: to see and edit the store in edit mode, run this once in the command bar and save the place:
   ```lua
   require(game.ServerScriptService.Server.StoreBuilder).Build()
   ```
   If a `Store` already exists, the server uses it and only reapplies the lighting.

## Where things live

| Studio location | Source | What it does |
|---|---|---|
| `ReplicatedStorage.Shared.Config` | `src/shared/Config.lua` | Global tunables (clean timing, sprint, flashlight, PSX look, sounds). Pulls in the Data tables. |
| `ReplicatedStorage.Shared.Data.*` | `src/shared/Data/*.lua` | Content as data: `Nights`, `Events`, `Modifiers`, `Stores`, `Upgrades`, `Monetization` |
| `ReplicatedStorage.Shared.Rules` | `src/shared/Rules.lua` | Resolves a night + modifiers into the numbers a shift runs on (server and clients) |
| `ReplicatedStorage.Shared.Clock` | `src/shared/Clock.lua` | Maps shift seconds to the 2:00–6:00 AM clock |
| `ReplicatedStorage.Remotes` | `default.project.json` | `ReadyUp`, `RequestCoffee`, `Results`, `PayoffCue`, `ShowNote`, `Flashlight`, `Cleaned` |
| `ServerScriptService.Server` | `src/server/init.server.lua` | Entry point and Studio-only `_G.ClosingShift` test commands |
| `…Server.StoreBuilder` | `src/server/StoreBuilder.lua` | Store layout, props, materials, PSX lighting |
| `…Server.RoundManager` | `src/server/RoundManager.lua` | Lobby → Shift → Payoff or Lights out → Results, driven by the night's rules |
| `…Server.SpillService` | `src/server/SpillService.lua` | Spawns spills, server-validated cleaning, the final back-room spill |
| `…Server.EventDirector` | `src/server/EventDirector.lua` | Runs the night's events and power cuts |
| `…Server.Events.*` | `src/server/Events/*.lua` | One module per "wrong" event, registered by file name |
| `…Server.Payoff` | `src/server/Payoff.lua` | Back-room reveal and the note prompt |
| `…Server.DataService` | `src/server/DataService.lua` | DataStore: best time, total cleaned, banked coffees |
| `…Server.Leaderboard` | `src/server/Leaderboard.lua` | OrderedDataStore top 10, drawn on the board by the counter |
| `…Server.Badges` / `Monetization` / `Mop` | `src/server/*.lua` | Badge awards, pass/product handling, the Mop tool |
| `StarterPlayerScripts.Client` | `src/client/init.client.lua` | Starts the client modules below |
| `…Client.Controls` / `Movement` | `src/client/*.lua` | Keyboard/gamepad/touch bindings; sprint + stamina (owns WalkSpeed) |
| `…Client.CameraFx` / `Overlay` | `src/client/*.lua` | FOV, head-bob, camera snap; scanlines, pixel grid, vignette, flicker |
| `…Client.Viewmodel` / `Flashlight` | `src/client/*.lua` | First-person mop; flashlight with battery |
| `…Client.SoundFx` / `Juice` | `src/client/*.lua` | Ambient sound bed and stings; clean feedback (particles, +1, ka-ching) |
| `…Client.Hud` / `Prompts` / `LightsFx` / `PayoffFx` | `src/client/*.lua` | HUD and results, prompt gating + touch MOP button, light flicker, payoff camera |

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
```

## Sounds

Sound effects come from Pro Sound Effects and APM (licensed for every Roblox experience) plus a few free
Creator Store uploads; all were checked to load. The IDs and what each is for are in `Config.Sounds`.

## Linting

`selene src` checks the code with the minimal Roblox std stub in `rbx.yml`. It catches syntax errors and common Lua mistakes, but it is not a Luau type checker. Studio's Script Analysis window is where `--!strict` type errors show up.
