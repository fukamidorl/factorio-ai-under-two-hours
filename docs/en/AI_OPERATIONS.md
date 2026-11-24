# AI operating guide

[Human README](../../README.md) · [Development history](DEVELOPMENT_HISTORY.md) · [日本語](../ja/AI_OPERATIONS.md) · [简体中文](../zh-Hans/AI_OPERATIONS.md)

## Interpret the request

| Request | Operating meaning |
| --- | --- |
| “Same seed and route” or “from scratch” | Generate a fresh base-game map before player creation in Factorio 2.1.25 from `world/map-gen-settings.json`. Keep map settings and build coordinates fixed along with the seed. Read `manifest.json` for runtime requirements. |
| “Show the game” | Choose `visible`. It opens with the engineer's view and switches to in-game cameras for mining, power, research and the silo. Keep the window visible and leave the victory dialog on screen. |
| “Under two hours” | Use game time. The qualifying event must occur at a world tick below `432000`. Fields ending in `_elapsed` start at automation startup. Fields ending in `_world_time` include the intro. Measure real elapsed time separately when requested. |
| “Fix it if it stalls” | Diagnose the active run first. When testing a change, keep the baseline and candidate runs available and use logs to check the change and its outcome. |
| “Earn achievements” | Check achievement eligibility in a regular base-game playthrough. The results here measure Lua-assisted construction and supply. |

Use the user's latest instruction, the [manifest](../../manifest.json) for execution requirements, the [launcher](../../run_route.py) and [Lua mod](../../mod/first-rocket-route-check_0.1.0/) for behavior, and the [verification record](../../reference/package_verification.json) for measured results. Resolve conflicts between translations using the implementation and those records. Historical saves and times document the conditions of earlier experiments.

Use the request to determine whether to replay or improve the route, whether to show the window, and whether to confirm launch or follow the run through delivery. Start a replay with the packaged route. When improving it, identify the affected stage and its comparison baseline before editing.

## Launch and monitor

Run these commands in the repository root. Use a new name for each attempt and retain the baseline directory under `runs/<name>/`.

~~~powershell
py -3 -X utf8 .\run_route.py check
py -3 -X utf8 .\run_route.py visible watch-01
py -3 -X utf8 .\run_route.py report watch-01
~~~

Use `headless verify-01` for a complete run measured through the logs. The visible mode's `launched` result records the launch request. When Steam takes over, check its launch dialog and `factorio-current.log`, then use `opening-start.json` and `report` to confirm the world is progressing. Headless mode waits for the Factorio test run to finish.

The launcher places the dedicated mod in a write directory for this run. When using screen controls to inspect Steam's prompt or the game, use the launcher and telemetry for execution and progress. See the following page for how the earlier MCP and single-plate tests used separate tools. [Running Factorio and tools used](METHOD_AND_TOOLS.md)

## Verify the outcome

- **Visible.** Confirm `satellite-loaded`, `launch` and `victory` in order. `goal-met` requires `victory_world_tick < 432000`. A snapshot taken during the victory dialog can precede delivery and the update of the launch counters.
- **Headless.** Confirm `satellite-loaded`, `launch` and `delivery` in order. The time criterion is `launch_world_tick < 432000`. At completion, verify launcher exit code 0, `goal-met` and `space_science` of 1,000. The test mode uses the actual launch and delivery events and counters.
- `time-missed` means the mode finished beyond the time target. `starting`, `opening` and `running` are progress states. For `failed`, read `error` and the relevant log. Report a finish time with the corresponding completion evidence.

The packaged headless reference recorded launch at `397078` ticks and delivery at `397647` ticks from automation startup. Its launch world tick was `398432`. The earlier full visible run recorded launch at `406737` and victory at `406738` elapsed ticks. The packaged visible run was rechecked through its camera switch after steam power. [Package events](../../reference/package_verification.json) · [Earlier run events](../../reference/confirmed_runs.json)

## Diagnose a problem

Each run writes to `runs/<name>/`. The mod writes to that directory's `script-output/`. Find the earliest stalled milestone and the tick at which you observed it.

| Symptom | Evidence and action |
| --- | --- |
| Version or checksum failure in `check` | Verify the path given to `--factorio` and the executable's `--version`. Get a fresh copy if an input differs from the manifest. If this only happens after a Windows Git checkout, check `.gitattributes` and line-ending conversion. Record deliberately modified inputs as a separate comparison. |
| Stalls at startup | Check `world-generation.log` for map creation, then `run.log` and `factorio-current.log` for loading. In visible mode, check Steam's custom-arguments dialog and whether the game is paused. |
| Initial mining or steam power stalls | Read `opening-error.json` and the current task in `supply-trial.json`. Check location, starting inventory, coal, water, the active water intake, and collisions with poles or crash debris. |
| Research stalls | Compare `through-latest.json` and `through-stream.jsonl`. Read `research`, `active_labs`, `progress` and science production and consumption by color. Check `steam_mw`, `steam_capacity_mw` and equipment `status` to identify the first missing pack or part of the power supply. |
| Installed machines produce too little | Inspect `warehouse`, `launch_reserve`, machine status and production per interval. Follow ore output, fuel, power and water, then machine input and output. Compare installed capacity with running equipment. |
| Purple science, yellow science and launch inventory compete | Follow stone, bricks, rails, modules and electric furnaces for purple science. Check shared processing units and low density structures, all three refinery outputs, cracking, water and plastic. Compare remaining science requirements with silo reserves before changing allocations. |
| Cannot place the silo or launch is slow | Inspect crash debris and power connections, `blocked_sites`, reused assemblers, and the reserves for the silo, research and the launch. Verify the four speed module 3s and identify the last observed event among loading, launch and delivery. |
| Camera stops updating | Compare `watch-error.txt` and `watch-latest.json` with production logs. Check the game view and the factory's progress independently. |

`through-stream.jsonl` contains minute snapshots and milestone events. Use multiple updates when diagnosing lack of progress. Test changes with the same map generation settings, measure throughput, stock and power in the affected interval, then verify through launch and delivery. Record effects on downstream stages.

Start code inspection in `opening.lua` for mining and initial steam power, `design.lua` for layouts and research order, `factory.lua` for construction, production, distribution and launch, or `watch.lua` for the display and camera. `control.lua` ties those modules to startup conditions and events.

For handoff, include mode, version, seed, run name or revision, last measured tick, first problem, specific fields or log entries, the change tried and whether it was verified in a full run. Extract the necessary evidence before sharing logs publicly.
