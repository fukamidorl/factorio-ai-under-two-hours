# Operating the Factorio replay

The default replay uses a fixed map and a scripted Lua route. Use the existing runner so the input and game version can be verified.

```powershell
python ./check_kit.py
python ./4263722700_AI別運用/operate.py replay --id replay-01
python ./4263722700_AI別運用/operate.py status --id replay-01
```

1. Start the replay with a new ID. Follow that same ID while the process is running. `status` can be called from a second terminal.
2. For the pinned headless route, report success when `state=matched` and `landing_pad_space_science=1000` accompany `delivery_world_tick=339287`. The rocket ascent finishes at tick 338718. These are game-world ticks. Use `timing_s` for wall time.
3. An exit code of 2 means that the result still needs evidence. Check the original run ID and its `4263722700_工数改善/results/<ID>/summary.json`. For exit code 1, inspect the reason, the Factorio build, and the input hash before starting a new run with a different ID.
4. The command `operate.py practice` emits mock cases for agents that can inspect evidence but cannot run the game. Report practice outcomes as simulated checks.

For the visual route, follow the README and query `run_route.py report <ID> --require-delivery` after the victory screen. For the manual checkpoint, follow the separate Steam instructions. The visual timing and Steam confirmation belong to their documented runs.

Report the version and build, seed, mode, world ticks for ascent and delivery, pad count, and whether the run matched. Keep a copy of the expected reference when testing a modified route.

[日本語の手順](README.md) · [English instructions](README.en.md) · [简体中文说明](README.zh-Hans.md)
