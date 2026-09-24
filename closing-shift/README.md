# CLOSING SHIFT

You and up to 3 friends work the last shift at a 24-hour convenience store. Mop every spill before 6:00 AM. The store gets wrong as the night goes on. The last spill is in the back room.

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
| `ReplicatedStorage.Shared.Config` | `src/shared/Config.lua` | Every tunable number, plus all badge, game pass and dev product IDs |
| `ReplicatedStorage.Shared.Clock` | `src/shared/Clock.lua` | Maps shift seconds to the 2:00–6:00 AM clock |
| `ReplicatedStorage.Remotes` | `default.project.json` | `ReadyUp`, `RequestCoffee`, `Results`, `PayoffCue`, `ShowNote` |
| `ServerScriptService.Server` | `src/server/init.server.lua` | Entry point and Studio-only `_G.ClosingShift` test commands |
| `…Server.StoreBuilder` | `src/server/StoreBuilder.lua` | Store layout, PSX lighting, Atmosphere, ColorCorrection |
| `…Server.RoundManager` | `src/server/RoundManager.lua` | Lobby → Shift → Payoff or Lights out → Results |
| `…Server.SpillService` | `src/server/SpillService.lua` | Spawns spills, server-validated cleaning, the final back-room spill |
| `…Server.EventDirector` | `src/server/EventDirector.lua` | The six "wrong" events |
| `…Server.Payoff` | `src/server/Payoff.lua` | Back-room reveal and the note prompt |
| `…Server.DataService` | `src/server/DataService.lua` | DataStore: best time, total cleaned, banked coffees |
| `…Server.Leaderboard` | `src/server/Leaderboard.lua` | OrderedDataStore top 10, drawn on the board by the counter |
| `…Server.Badges` | `src/server/Badges.lua` | Badge awards |
| `…Server.Monetization` | `src/server/Monetization.lua` | Industrial Mop pass and Extra Coffee product |
| `…Server.Mop` | `src/server/Mop.lua` | The Mop tool, built from Parts |
| `StarterPlayerScripts.Client` | `src/client/*` | HUD, scanlines, light flicker, prompt gating, payoff camera |

## Playtest commands (Studio only)

While playing, switch the command bar to **Server** and run:

```lua
_G.ClosingShift.Start()              -- skip the intermission
_G.ClosingShift.CleanAll()           -- clean every spill (tests the win, payoff and results flow)
_G.ClosingShift.CleanOne()
_G.ClosingShift.Timeout()            -- end the shift now (tests the lose flow)
_G.ClosingShift.Event("Mannequin")   -- SignGlitch, Footprints, DoorChime, IdenticalAisle, LightsOut, Mannequin
```

## Sounds used

All of these are built-in engine sounds, so there's nothing to approve and nothing to get moderated. Swap them in `Config.Sounds`.

- Mop squeak: `rbxasset://sounds/action_swim.mp3`
- Clean splash: `rbxasset://sounds/impact_water.mp3`
- Door chime: `rbxasset://sounds/electronicpingshort.wav`
- Lights-out buzz: `rbxasset://sounds/clickfast.wav`

## Linting

`selene src` checks the code with the minimal Roblox std stub in `rbx.yml`. It catches syntax errors and common Lua mistakes, but it is not a Luau type checker. Studio's Script Analysis window is where `--!strict` type errors show up.
