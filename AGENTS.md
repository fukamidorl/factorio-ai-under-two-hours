# Factorio first-rocket route

Read the operating guide in the user's language before running or changing the route.

| Language | Operator guide | Game and tools | Development history | Release preparation |
| --- | --- | --- | --- | --- |
| 日本語 | [AI操作手順](docs/ja/AI_OPERATIONS.md) | [Factorioの扱い方と使用ツール](docs/ja/METHOD_AND_TOOLS.md) | [開発の時系列](docs/ja/DEVELOPMENT_HISTORY.md) | [公開準備](docs/ja/PUBLISHING.md) |
| English | [AI operations](docs/en/AI_OPERATIONS.md) | [Running Factorio and tools used](docs/en/METHOD_AND_TOOLS.md) | [Development history](docs/en/DEVELOPMENT_HISTORY.md) | [Release preparation](docs/en/PUBLISHING.md) |
| 简体中文 | [AI 操作手册](docs/zh-Hans/AI_OPERATIONS.md) | [游戏运行方法与所用工具](docs/zh-Hans/METHOD_AND_TOOLS.md) | [开发时间线](docs/zh-Hans/DEVELOPMENT_HISTORY.md) | [发布准备](docs/zh-Hans/PUBLISHING.md) |

Use the [manifest](manifest.json) for the runtime version, seed, input checksums and timing threshold. For a baseline replay, choose a new run name. The launcher generates the starting save locally from the fixed map settings. Read the mode-specific result in `report` and keep game time and real elapsed time distinct.

Use visible mode when the user wants to watch Factorio. Use headless mode for repeatable comparisons. Before changing the route, keep a runnable baseline and use a separate candidate for the change. Share a compact result with the version, seed, mode, measured event ticks and evidence.

The test PC, Factorio build and Codex development settings are recorded for context. Use game ticks for comparisons and measure wall time separately on the machine used. [Run environment](reference/run_environment.json)
