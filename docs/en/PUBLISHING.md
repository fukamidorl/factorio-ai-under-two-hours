# Prepare a GitHub release

[Human README](../../README.md) · [AI operations](AI_OPERATIONS.md) · [日本語](../ja/PUBLISHING.md) · [简体中文](../zh-Hans/PUBLISHING.md)

## Release details

| Item | Value |
| --- | --- |
| Title | How to Have AI Beat Factorio in Under Two Hours |
| Publishing credit | Factory Launch Project |
| GitHub repository name | `factorio-ai-under-two-hours` |
| License | [MIT](../../LICENSE) for original code, documentation, and design data |

## GitHub About description

> Replay an AI-built Factorio 2.1.25 route that launched a satellite in 1:50:18 of game time. ChatGPT did nearly all the work.

## Release description

> This Lua mod and Windows launcher automate a satellite launch from a fresh Factorio 2.1.25 base-game map with fixed seed 4263722700. ChatGPT did nearly all the work. The user set the goal, shared reference speedruns, suggested improvements, and confirmed the final launch. The headless run launched at 1:50:18 of in-game time and delivered 1,000 space science packs. Please update the run record when redistributing the project or publishing an improved version.

## Repository contents

| Path | What it provides |
| --- | --- |
| `README*.md`, `AGENTS.md` and `docs/` | Entry points for humans and agents, development history and release preparation in English, Japanese and Simplified Chinese. |
| `run_route.py`, `mod/` and `manifest.json` | The verified launcher, project Lua code, layouts, research order, requirements and SHA-256 checksums. Git attributes keep the checked input bytes stable on Windows. |
| `world/` | Map generation settings. The installed Factorio 2.1.25 uses them to create a freeplay save before player creation in the run directory. |
| `reference/` | Extracted run events and verification conditions for the earlier runs, packaged headless run and packaged visible startup test. |

The public ZIP contains the prepared source and documentation. Factorio and its scenario assets come from the player's installation. Generated `runs/` directories, raw logs, personal settings, and save files stay on the machine used for the run. Development notes link to the original speedrun sources. [Factorio terms of service](https://www.factorio.com/terms-of-service#intellectual-property-rights-and-sharing)

## Public identity and email

The repository URL displays the owner's user or organization name. Use a GitHub namespace suitable for public display. The public ZIP is a source archive without commit history. For public commits, configure the GitHub-provided `noreply` address in this repository and check both author and committer email fields. GitHub also offers account email privacy and blocks for command-line pushes that expose a personal email address. [Setting a commit email address](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address) · [Blocking pushes that expose personal email](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/blocking-command-line-pushes-that-expose-your-personal-email-address)

## Redistribution and run records

Keep the copyright and permission notices when redistributing MIT-licensed material. Updating the run record is a request to people who publish improved versions. Include the in-game launch time, Factorio version, seed, run mode, and main changes when timing a run. The headless comparison time is `1:50:18`. The earlier visible demonstration launched at `1:52:59`. [License](../../LICENSE) · [Measured results](../../reference/package_verification.json)

Extract the release ZIP into a fresh directory and run `check` to verify the game version and file checksums. Record the tag or commit used for verification with each release. For a problem report, include the game version and mode, `check` and `report` results, the stage and tick where the problem began, and a log excerpt with personal details removed. [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
