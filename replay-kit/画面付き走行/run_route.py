"""Launch or verify the seed-4263722700 first-rocket route on Windows."""

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parent
MOD = "first-rocket-route-check"
MOD_FOLDER = f"{MOD}_0.1.0"
TICKS_PER_SECOND = 60
DEFAULT_EXE = (
    Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"))
    / "Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
)


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def snapshot(path):
    try:
        return read_json(path)
    except (FileNotFoundError, PermissionError, UnicodeDecodeError, json.JSONDecodeError):
        # Factorio may be writing its current snapshot between reads.
        return None


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def emit(data):
    print(json.dumps(data, ensure_ascii=False), flush=True)


def run_name(value):
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,39}", value):
        raise argparse.ArgumentTypeError("Use 1–40 ASCII letters, digits, underscores or hyphens.")
    if re.fullmatch(r"CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]", value, flags=re.IGNORECASE):
        raise argparse.ArgumentTypeError("Choose another run name. This one is reserved on Windows.")
    return value


def preflight(executable, manifest):
    if sys.platform != "win32":
        raise RuntimeError("This launcher uses the Windows Factorio executable.")
    executable = executable.expanduser().resolve(strict=True)
    game_data = executable.parents[2] / "data"
    if not (game_data / "base" / "info.json").is_file():
        raise RuntimeError(f"Factorio data directory was not found at {game_data}")

    for name, expected in manifest["sha256"].items():
        actual = sha256((ROOT / name).read_bytes()).hexdigest()
        if actual != expected:
            raise RuntimeError(f"Checksum mismatch for {name}")

    completed = subprocess.run(
        [str(executable), "--version"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=25,
        check=True,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    expected = manifest["factorio_version"]
    match = re.search(r"^Version:\s*(\d+\.\d+\.\d+)", completed.stdout, re.MULTILINE)
    if not match or match.group(1) != expected:
        version = completed.stdout.splitlines()[0] if completed.stdout else "unknown"
        raise RuntimeError(f"Expected Factorio {expected}. Found {version}")

    return executable, game_data


def prepare(executable, directory, game_data, manifest, mode):
    directory.mkdir(parents=True)
    mods = directory / "mods"
    mods.mkdir()
    (directory / "saves").mkdir()
    base_mods = [
        {"name": name, "enabled": name == "base"}
        for name in ("base", "elevated-rails", "quality", "recycler", "space-age")
    ]
    write_json(mods / "mod-list.json", {"mods": base_mods})

    config = directory / "config.ini"
    contents = f"[path]\nread-data={game_data.as_posix()}\nwrite-data={directory.as_posix()}\n"
    if mode == "visible":
        contents += "\n[general]\nlocale=ja\n\n[graphics]\nfull-screen=false\n"
    config.write_text(contents, encoding="utf-8")

    world = directory / "input-world.zip"
    generation_log = directory / "world-generation.log"
    with generation_log.open("w", encoding="utf-8") as stream:
        created = subprocess.run(
            [
                str(executable), "--config", str(config), "--mod-directory", str(mods),
                "--create", str(world), "--map-gen-settings", str(ROOT / manifest["map_gen_settings"]),
                "--map-gen-seed", str(manifest["seed"]),
            ],
            cwd=directory,
            stdin=subprocess.DEVNULL,
            stdout=stream,
            stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW,
            timeout=120,
        )
    if created.returncode != 0 or not world.is_file():
        raise RuntimeError(f"Factorio could not generate the starting world. See {generation_log}")

    mod = mods / MOD_FOLDER
    shutil.copytree(ROOT / "mod" / MOD_FOLDER, mod)
    write_json(mods / "mod-list.json", {"mods": [*base_mods, {"name": MOD, "enabled": True}]})
    visible = mode == "visible"
    if visible:
        # Steam reads the App ID from the working directory for direct launches.
        (directory / "steam_appid.txt").write_text("427520\n", encoding="ascii")
    timing = manifest["modes"][mode]
    policy = (
        f"return {{speed={timing['speed']},horizon={timing['horizon_ticks']},"
        f"start_tick={manifest['start_world_tick']},"
        f"visible={'true' if visible else 'false'},"
        f"test_run={'false' if visible else 'true'}}}\n"
    )
    (mod / "trial-policy.lua").write_text(policy, encoding="ascii")

    write_json(directory / "run.json", {
        "mode": mode,
        "seed": manifest["seed"],
        "input_world_sha256": sha256(world.read_bytes()).hexdigest(),
    })
    return config, mods, world


def clock(ticks, *, round_seconds=True):
    offset = TICKS_PER_SECOND // 2 if round_seconds else 0
    seconds = (ticks + offset) // TICKS_PER_SECOND
    hours, seconds = divmod(seconds, 3600)
    minutes, seconds = divmod(seconds, 60)
    return f"{hours}:{minutes:02}:{seconds:02}"


def status(directory, manifest):
    run = read_json(directory / "run.json")
    output = directory / "script-output"
    summary = {
        "state": "starting",
        "mode": run["mode"],
        "seed": run["seed"],
        "directory": str(directory),
    }
    for name, label in (
        ("opening-start.json", "start"),
        ("opening-error.json", "opening_error"),
    ):
        data = snapshot(output / name)
        if data is not None:
            summary[label] = data
    if (output / "watch-error.txt").is_file():
        summary["camera_error_file"] = str(output / "watch-error.txt")
    if "opening_error" in summary:
        return summary | {"state": "failed", "error": summary["opening_error"]["problem"]}

    latest = snapshot(output / "through-latest.json")
    if latest is None:
        opening = snapshot(output / "supply-trial.json")
        if opening:
            return summary | {
                "state": "opening",
                "elapsed_ticks": opening["elapsed_ticks"],
                "elapsed": clock(opening["elapsed_ticks"]),
                "stage": opening.get("stage"),
                "task": opening.get("task"),
            }
        return summary

    elapsed = latest["tick"]
    origin = latest["world_tick"] - elapsed
    summary.update(
        state="running",
        elapsed_ticks=elapsed,
        elapsed=clock(elapsed),
        profile=latest["profile"],
        research=latest.get("research"),
        active_labs=latest["active_labs"],
        steam_mw=latest["steam_mw"],
        steam_capacity_mw=latest["steam_capacity_mw"],
        silo_parts=latest["silo_parts"],
    )
    if latest.get("error"):
        return summary | {"state": "failed", "error": latest["error"]}
    if latest["seed"] != manifest["seed"] or latest["base"] != manifest["factorio_version"]:
        return summary | {"state": "failed", "error": "Unexpected map seed or base version"}

    recorded = latest["events"]
    events = {
        name: recorded[name]["tick"]
        for name in (
            "satellite-loaded", "launch-ordered", "launch", "victory",
            "cargo-pod-delivered", "delivery",
        )
        if name in recorded
    }
    summary["events"] = events
    delivered = (
        "delivery" in events
        and latest["rockets"] == 1
        and latest["satellites"] == 1
        and latest["space_science"] >= 1000
    )
    if delivered:
        delivery = events["delivery"]
        delivery_world_tick = origin + delivery
        summary.update(
            delivery_elapsed=clock(delivery),
            delivery_world_tick=delivery_world_tick,
            delivery_world_time=clock(delivery_world_tick, round_seconds=False),
            space_science=latest["space_science"],
        )
        if "launch" in events:
            summary["ascent_to_delivery_ticks"] = delivery - events["launch"]
    if not {"satellite-loaded", "launch"} <= events.keys():
        return summary

    loaded, launch = (events[name] for name in ("satellite-loaded", "launch"))
    if not 0 <= loaded <= launch <= elapsed:
        return summary | {"state": "failed", "error": "Unexpected launch event order"}
    world_launch = origin + launch
    summary.update(
        start_world_tick=origin,
        launch_elapsed=clock(launch),
        launch_world_tick=world_launch,
        launch_world_time=clock(world_launch, round_seconds=False),
    )
    if run["mode"] == "headless":
        if not delivered:
            return summary
        if not launch <= events["delivery"] <= elapsed:
            return summary | {"state": "failed", "error": "Unexpected delivery event order"}
        target_tick = world_launch
    else:
        victory = events.get("victory")
        if victory is None:
            return summary
        if not launch <= victory <= elapsed:
            return summary | {"state": "failed", "error": "Unexpected victory event order"}
        target_tick = origin + victory
        summary.update(
            victory_elapsed=clock(victory),
            victory_world_tick=target_tick,
            victory_world_time=clock(target_tick, round_seconds=False),
        )
    summary["state"] = (
        "goal-met" if target_tick < manifest["goal_world_ticks_exclusive"] else "time-missed"
    )
    return summary


def delivery_status(directory, manifest):
    """Judge visible delivery using the same snapshot as the ordinary report."""
    try:
        report = status(directory, manifest)
    except (FileNotFoundError, json.JSONDecodeError):
        # The launcher may still be preparing the run or writing run.json.
        return {"state": "awaiting-delivery", "reason": "run_metadata_pending",
                "delivery_verified": False}, 2
    except (KeyError, TypeError, ValueError, OSError):
        return {"state": "failed", "reason": "invalid_run_evidence",
                "delivery_verified": False}, 1

    phase = report["state"]
    report.update(legacy_state=phase, delivery_verified=False)
    if report["mode"] != "visible" or report["seed"] != manifest["seed"]:
        return report | {"state": "failed", "reason": "unexpected_seed_or_mode"}, 1
    if phase in {"failed", "time-missed"}:
        return report | {"reason": "run_failed" if phase == "failed" else "victory_time_missed"}, 1

    events = report.get("events", {})
    if "delivery" not in events:
        return report | {"state": "awaiting-delivery", "reason": "delivery_event_pending"}, 2

    order = ("satellite-loaded", "launch-ordered", "launch", "victory", "cargo-pod-delivered", "delivery")
    ticks = [0, *(events.get(name) for name in order), report.get("elapsed_ticks")]
    world_tick = report.get("delivery_world_tick")
    if (
        phase != "goal-met"
        or report.get("space_science") != 1000
        or report.get("start_world_tick") != manifest["start_world_tick"]
        or type(world_tick) is not int
        or any(type(tick) is not int for tick in ticks)
        or ticks != sorted(ticks)
    ):
        return report | {"state": "failed", "reason": "inconsistent_delivery_evidence"}, 1
    if world_tick >= manifest["goal_world_ticks_exclusive"]:
        return report | {"state": "time-missed", "reason": "delivery_time_missed"}, 1
    return report | {"state": "delivery-verified", "reason": "delivery_verified",
                     "delivery_verified": True}, 0


def run_headless(command, directory, manifest, timeout):
    deadline = time.monotonic() + timeout
    log = directory / "run.log"
    with log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(
            command,
            cwd=directory,
            stdin=subprocess.DEVNULL,
            stdout=stream,
            stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        try:
            previous = None
            while child.poll() is None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError(f"Factorio timed out. See {log}")
                report = status(directory, manifest)
                progress = (report["state"], report.get("elapsed_ticks", 0) // 36_000)
                if progress != previous:
                    emit(report)
                    previous = progress
                try:
                    child.wait(timeout=min(3, remaining))
                except subprocess.TimeoutExpired:
                    pass
        finally:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=15)

    report = status(directory, manifest)
    report["engine_exit"] = child.returncode
    emit(report)
    if child.returncode == 0 and report["state"] == "goal-met" and "space_science" in report:
        return 0
    print(f"Headless run did not meet the completion check. See {log}", file=sys.stderr)
    return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="mode", required=True)
    for mode, help_text in (
        ("check", "Verify the installed Factorio version and package inputs."),
        ("headless", "Run in Factorio test mode and verify launch and delivery."),
        ("visible", "Open the game window and start automatic play."),
        ("report", "Read a run's current status."),
    ):
        entry = commands.add_parser(mode, help=help_text)
        if mode != "report":
            entry.add_argument("--factorio", type=Path, default=DEFAULT_EXE)
        if mode != "check":
            entry.add_argument("name", type=run_name)
        if mode == "report":
            entry.add_argument("--require-delivery", action="store_true",
                               help="Verify arrival within the target, with 1,000 packs in the pad.")
        if mode == "headless":
            entry.add_argument("--timeout", type=int, default=1800, help="Real-time limit in seconds.")
    args = parser.parse_args(argv)
    if args.mode == "headless" and args.timeout <= 0:
        parser.error("--timeout must be positive")

    manifest = read_json(ROOT / "manifest.json")
    if args.mode == "report":
        directory = ROOT / "runs" / args.name
        if args.require_delivery:
            result, exit_code = delivery_status(directory, manifest)
            emit(result)
            return exit_code
        report = status(directory, manifest)
        emit(report)
        return int(report["state"] in {"failed", "time-missed"})

    exe, game_data = preflight(args.factorio, manifest)
    if args.mode == "check":
        emit({
            "state": "ready",
            "factorio": str(exe),
            "version": manifest["factorio_version"],
            "seed": manifest["seed"],
            "verified_files": len(manifest["sha256"]),
        })
        return 0

    directory = ROOT / "runs" / args.name
    if directory.exists():
        raise FileExistsError(f"Run already exists. Choose another name. {directory}")
    config, mods, world = prepare(exe, directory, game_data, manifest, args.mode)
    command = [str(exe), "--config", str(config), "--mod-directory", str(mods)]
    if args.mode == "headless":
        test_ticks = manifest["start_world_tick"] + manifest["modes"]["headless"]["horizon_ticks"] + 60
        command += ["--test-save", str(world), "--test-ticks", str(test_ticks)]
        return run_headless(command, directory, manifest, args.timeout)

    command += ["--load-game", str(world), "--disable-migration-window"]
    with (directory / "run.log").open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(
            command,
            cwd=directory,
            stdin=subprocess.DEVNULL,
            stdout=stream,
            stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS,
        )
    emit({"state": "launched", "launcher_pid": child.pid, "directory": str(directory)})
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
