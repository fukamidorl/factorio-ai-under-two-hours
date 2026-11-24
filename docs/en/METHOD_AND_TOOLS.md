# Running Factorio and tools used

[Human README](../../README.md) · [AI operations](AI_OPERATIONS.md) · [日本語](../ja/METHOD_AND_TOOLS.md) · [简体中文](../zh-Hans/METHOD_AND_TOOLS.md)

## Run the package

Use 64-bit Windows, an installed copy of **Factorio 2.1.25**, and Python 3.11 or later. Verification used Steam build 88022. To use a game installed elsewhere, add `--factorio "D:\Games\Factorio\bin\x64\factorio.exe"` to each check and launch command. [Factorio’s official version archive](https://www.factorio.com/download/archive/2.1.25)

1. Extract the release ZIP and open PowerShell in the directory containing `run_route.py`. Run `check` to verify the game version and package checksums. At launch, Factorio generates the starting save from `world/map-gen-settings.json`.
2. **To watch**, use `visible` below. If Steam asks about custom arguments, verify that the settings, mod directory and save point to this run under `runs/watch-01/` and choose **Continue**. If Factorio is already open, save any work you want to keep and close it before starting the visible run.
3. Watch mining, power and research in the game window. It opens on the engineer and later switches between in-game cameras. The shipped configuration and camera labels are in Japanese. Launch is shown at normal speed and the victory dialog displays the result.
4. **To verify through delivery without a window**, use `headless`. The launcher runs Factorio with `--test-save` and checks satellite launch and delivery of 1,000 space science packs. Read the result with `report` once the PowerShell command finishes.

~~~powershell
py -3 -X utf8 .\run_route.py check
py -3 -X utf8 .\run_route.py visible watch-01
py -3 -X utf8 .\run_route.py report watch-01
~~~

~~~powershell
py -3 -X utf8 .\run_route.py headless verify-01
py -3 -X utf8 .\run_route.py report verify-01
~~~

Choose a new name for each run. To stop a visible run early, save if needed and close that game window. To interrupt headless mode, press `Ctrl+C` in PowerShell. The launcher stops the process it started for that run. `report` reads the saved telemetry, so an interrupted run shows the last recorded stage. If someone is watching, leave the victory dialog on screen. To observe cargo delivery in visible mode, continue from that dialog. The game writes telemetry to `runs/<run-name>/script-output/`. Visible mode also writes silo and launch screenshots there.

## The dedicated rocket-route mod

**`first-rocket-route-check` 0.1.0** is the Lua mod built to launch a satellite on this seed. The launcher uses the base game to generate `runs/<run-name>/input-world.zip`, writes generation output to `world-generation.log`, and records the save's SHA-256 in `run.json`. It then copies the route mod from `mod/` into the run directory and generates `trial-policy.lua` for the selected mode. `design.lua` holds placement and research order. `watch.lua` controls the camera. [Mod source](../../mod/first-rocket-route-check_0.1.0/) · [Launcher](../../run_route.py)

- **Opening.** After the intro, Lua directs walking, mining and crafting. The game supplies the default burner mining drill, stone furnace and wood. Building consumes inventory items.
- **After initial steam power.** Lua collects materials mined or produced in the game into a scripted stock table and feeds furnaces, assemblers, power equipment and labs directly. That handles part of the transport, construction and site clearance. The mod uses produced equipment, checks for collisions, places it and queues research.
- **Launch.** Factorio runs mining, smelting, manufacturing, power and research. Lua loads the produced satellite into the silo, enables automatic launch, and records launch and delivery to the cargo landing pad.

When comparing with human runs, include the Lua-assisted construction and distribution and the game-speed settings.

## Achievement candidates

These are the main base-game achievements to aim for on this route in Factorio 2.1.25. The packaged run logs cover launch, production, and equipment. [Achievement definitions for 2.1.25](https://github.com/wube/factorio-data/blob/2.1.25/base/prototypes/achievements.lua)

| Achievement | Requirement |
| --- | --- |
| Automate this! | Place an assembling machine 1. |
| Eco unfriendly | Complete oil processing research. |
| Mass production 1 | Produce 10,000 electronic circuits in total. |
| Smoke me a kipper, I'll be back for breakfast | Launch a rocket into space. |
| No time for chitchat | Launch a rocket within 15 in-game hours. |
| There is no spoon | Launch a rocket within 8 in-game hours. |
| Steam all the way | Launch a rocket without placing any solar panels. |
| Raining bullets | Launch a rocket without placing any laser turrets. |

The packaged headless run launched at 1:50:18 of in-game time from the start of automation and produced 130,478 electronic circuits. It placed zero solar panels and zero laser turrets and used 100 solar panels to craft the satellite. [Packaged run evidence](../../reference/package_verification.json)

**Verified on Steam.** There is no spoon unlocked at 21:02 Japan time on November 22, 2026 in an earlier trial on seed `210539101`. The Factorio 2.1.24 save was resumed shortly before victory with the custom mod disabled and reached victory at 5:49:24 in-game. The Steam page also showed related unlocks that day. [Unlock times and trial history](DEVELOPMENT_HISTORY.md)

Factorio normally records unlocks with the route mod enabled in its modded achievement list. For Steam achievements, meet the conditions in unmodded Freeplay with achievements enabled. Reducing enemy or pollution settings below their defaults disables some timed and equipment-restriction achievements. [Factorio Wiki on achievements](https://wiki.factorio.com/Achievements#Disabling_achievements)

To pursue Logistic network embargo after launch, complete a research project that consumes the delivered space science packs without placing active provider, buffer, or requester chests.

## Development and verification tools

| Tool | Where it was used |
| --- | --- |
| ChatGPT Codex with GPT-6.2 Sol | Route design, implementation, trial analysis and documentation. The project user reported using Extra High (`xhigh`) and Max (`max`) while tuning, and Max in the final stage. |
| Computer Use | Inspection of the Windows game window and Steam launch dialog, and checks during the visible demos. A Windows input helper handled held movement and mining inputs when testing the single-plate run. |
| Factorio LLM Use 0.1.1, `uv`, MCP and local RCON | Initial connection test on Factorio 2.1.24. It mined iron ore, smelted it and collected one iron plate to verify the general game controls. [Factorio LLM Use](https://github.com/Tsyklop/factorio-llm-use) |
| `visible-first-iron-demo` 0.1.0 | Dedicated visible single-plate demo on 2.1.24. After targeting the furnace material inventory via `defines.inventory.crafter_input`, the run ended at 1,310 elapsed game ticks with one iron plate in the player's inventory and zero in the furnace output. |
| `first-rocket-route-check` 0.1.0, Python and PowerShell | The current route from a fresh map to the satellite launch. Visible mode uses the game window. Headless mode uses Factorio test mode. Earlier integrated trials continued the same save on a local server and tracked delivery there. |
| Public speedrun videos and saves, Python, and Git | Comparison of human routes and production, log analysis, package validation and ZIP creation. [Development history](DEVELOPMENT_HISTORY.md) |

Reproduction requires the installed game, Python and the package. The Computer Use and Factorio LLM Use workflows above describe tools used during development and verification.

## Weekly allowance during development

The project user estimates that the **ChatGPT Pro 100** weekly allowance meter went from **roughly 100% to roughly 75% remaining** during project work. The **roughly 25 percentage points** describes the meter change. Exact observation times, other activity within that allowance window, and project-only tokens and cost were unrecorded. The meter tracks a different quantity from game ticks and the wall-clock time of a local replay. [Environment and usage record](../../reference/run_environment.json)

Allowance use varies with the model, reasoning effort, context processed and tools used. Treat the observation as a rough measure of the development workload at the time. [OpenAI’s usage guidance](https://learn.chatgpt.com/docs/pricing#usage-limits)
