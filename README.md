# How to Have AI Beat Factorio in Under Two Hours

**English** · [日本語](README.ja.md) · [简体中文](README.zh-Hans.md)

This project automates a satellite launch on a fresh **Factorio 2.1.25** base-game map with seed **4263722700**. It includes the map generation settings, a Lua mod that builds and supplies the factory, and a launcher for watching the run or checking it without a game window.

**ChatGPT did nearly all the work**, including route design, implementation, trials, verification, and documentation. The user set the goal, shared reference speedruns, suggested improvements, and confirmed the final launch. The publishing credit is **Factory Launch Project**.

## Watch or reproduce the run

Use Windows, Factorio 2.1.25 and Python 3.11 or later. Open PowerShell in this directory. The launcher uses Python's standard library. If Steam asks to launch with custom arguments, verify that the paths point to this run's directory and select **Continue**.

~~~powershell
py -3 -X utf8 .\run_route.py check
py -3 -X utf8 .\run_route.py visible watch-01
py -3 -X utf8 .\run_route.py report watch-01
~~~

For a headless run through launch and delivery, use `headless verify-01` in place of `visible watch-01`. Choose a new run name each time. If Factorio is installed outside Steam's default location, add `--factorio "D:\Games\Factorio\bin\x64\factorio.exe"` to the check and launch commands. You can replace `py -3` with the path to your Python executable.

The launcher uses the installed copy of Factorio to generate a starting save for each run, then opens it with the included **`first-rocket-route-check` 0.1.0** mod. If Factorio is already open, save any work you want to keep and close it before starting the visible run. [Factorio launch, viewing and exit instructions](docs/en/METHOD_AND_TOOLS.md)

## Measured results

| Run | Automation start to launch | Last confirmed result |
| --- | ---: | --- |
| Packaged route, headless | **1:50:18** | 1,000 space science packs delivered at 1:50:27 |
| Earlier full run with the game window | **1:52:59** | Victory screen displayed 1:53:21, including the intro |
| Earlier integrated run, repeated twice | **1:49:38** | Switched to a local server at minute 65 and received cargo at 1:49:47. All 173 recorded event ticks matched across the two runs. |

These are in-game times. The earlier full visible run reached the launch and victory screen. A later windowed test in the earlier package verified the camera switch after steam power. [Package verification](reference/package_verification.json) · [Earlier confirmed runs](reference/confirmed_runs.json)

The save starts before player creation. Lua controls movement, construction, the research queue, and transfers of items and fluids. The Factorio engine runs mining, manufacturing, power, research and the launch. Codex helped develop the route and the mod executes it during the timed run.

## Test environment

| Component | Configuration |
| --- | --- |
| PC | Intel Core i5-12450H (8 cores, 12 threads), 16 GB RAM, approximately 512 GB NVMe SSD |
| Rendering | GeForce RTX 3050 Ti Laptop GPU (about 4 GB dedicated VRAM, Direct3D 11). The PC also has Intel UHD Graphics. |
| OS | Windows 11 Home, 64-bit (build 26200) |
| Factorio | Steam 2.1.25 (build 88022), base game with Space Age disabled. The public package generates its starting save locally in 2.1.25. |
| Automation | `first-rocket-route-check` 0.1.0. The launcher was checked with Python 3.12.16. |

Development used **GPT-6.2 Sol in ChatGPT Codex**. According to the project user, reasoning effort alternated between **Extra High (`xhigh`) and Max (`max`)** during rehearsal tuning, then used **Max** in the final stage. Codex contributed to route design, implementation and trial analysis. The local Lua mod controls the game during reproduction.

Visible mode is configured for up to 12× speed and shows the launch at normal speed. With the locally generated map, the headless test took **about 7 minutes 7 seconds** from Factorio test startup to completion on this PC. The earlier tests recorded launch and delivery at the same game ticks. [Environment record](reference/run_environment.json) · [Package verification and repeat](reference/package_verification.json)

## Documentation

- [Development history](docs/en/DEVELOPMENT_HISTORY.md) traces the trials, runner references, user feedback, bottlenecks and applied changes.
- [AI operations](docs/en/AI_OPERATIONS.md) covers interpreting a request, monitoring a run, diagnosing problems and verifying completion.
- [Tools and development allowance](docs/en/METHOD_AND_TOOLS.md#development-and-verification-tools) explains the dedicated mod, Computer Use, the earlier Factorio LLM Use tests, and the project user's approximate Pro 100 meter observation.
- [Achievement candidates](docs/en/METHOD_AND_TOOLS.md#achievement-candidates) lists the launch, timing, and equipment conditions and explains how to attempt Steam achievements.
- [Release preparation](docs/en/PUBLISHING.md) covers distribution contents, measured results, licensing and the starting save.

## License and redistribution

Original project code, documentation, and design data are available under the MIT License. Retain the copyright and permission notices when redistributing them. Wube Software Ltd. retains the rights to Factorio and its assets. [MIT License](LICENSE) · [Factorio terms of service](https://www.factorio.com/terms-of-service#intellectual-property-rights-and-sharing)

**Please update the run record when you redistribute the project or publish an improved version.** For a timed run, include the in-game launch time, Factorio version, seed, run mode, and main changes. Times that beat 1:50:18 are welcome.
