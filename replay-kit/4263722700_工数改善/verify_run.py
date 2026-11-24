"""Verify a completed headless Factorio run against the pinned reference.

Exit 0 means an exact match. Exit 1 means failed or invalid evidence.
Exit 2 means the run has started, is progressing, or still lacks completion proof.
Use --engine-exit to pass the completed run_route.py process return code.
"""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import sys


EVENTS = ("satellite-loaded", "launch-ordered", "launch", "cargo-pod-delivered", "delivery")
COUNTS = {"rockets": 1, "satellites": 1, "space_science": 1000, "silo_parts": 0}
ROUTE_MOD = "first-rocket-route-check"
EXPECTED_MODS = {"base", ROUTE_MOD}
HEADER = re.compile(r"^.+;\s*Factorio (\d+\.\d+\.\d+) \(build (\d+), ([^)\r\n]+)\)\s*$", re.MULTILINE)
TEST_PASSED = re.compile(r"^\s*\d+(?:\.\d+)?\s+Info RunTest\.cpp:\d+: Test passed at tick (\d+)\s*$", re.MULTILINE)
GOODBYE = re.compile(r"^\s*(\d+(?:\.\d+)?)\s+Goodbye\s*$", re.MULTILINE)


class InvalidEvidence(ValueError):
    """A required input or observed result conflicts with the reference."""


class PendingEvidence(RuntimeError):
    """A live run has not yet produced adequate evidence."""

    def __init__(self, state, reason):
        super().__init__(reason)
        self.state = state


def require(condition, reason):
    if not condition:
        raise InvalidEvidence(reason)


def json_object(path):
    data = json.loads(path.read_bytes())
    require(isinstance(data, dict), f"{path.name} does not contain a JSON object.")
    return data


def read_required(path):
    try:
        return json_object(path)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise InvalidEvidence(f"Cannot read valid {path.name}.") from error


def read_live(path, terminal, missing_state, malformed_state="incomplete"):
    try:
        return json_object(path)
    except FileNotFoundError as error:
        if terminal:
            raise InvalidEvidence(f"Completed launcher did not produce {path.name}.") from error
        raise PendingEvidence(missing_state, f"Waiting for {path.name}.") from error
    except (PermissionError, UnicodeDecodeError, json.JSONDecodeError) as error:
        if terminal:
            raise InvalidEvidence(f"Completed launcher left unreadable {path.name}.") from error
        raise PendingEvidence(malformed_state, f"Waiting for a readable {path.name}.") from error


def check_digest(path, expected, label):
    require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected), f"Invalid SHA-256 for {label}.")
    try:
        actual = sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        raise InvalidEvidence(f"Cannot read {label}.") from error
    require(actual == expected, f"SHA-256 mismatch for {label}.")
    return actual


def child_path(root, relative):
    require(isinstance(relative, str) and bool(relative), "Invalid reference or manifest file name.")
    candidate = (root / relative).resolve()
    require(candidate.is_relative_to(root), "Reference or manifest file is outside its directory.")
    return candidate


def read_reference(baseline, route):
    spec = read_required(baseline)
    require(type(spec.get("schema_version")) is int and spec["schema_version"] == 1, "Unsupported baseline schema.")
    require(spec.get("mode") == "headless", "Baseline must use headless mode.")
    require(
        isinstance(spec.get("factorio_version"), str) and type(spec.get("factorio_build")) is int
        and type(spec.get("seed")) is int and type(spec.get("start_world_tick")) is int,
        "Baseline version, build, seed, or start tick is missing or invalid.",
    )

    manifest_path = route / "manifest.json"
    check_digest(manifest_path, spec.get("route_manifest_sha256"), "route manifest.json")
    manifest = read_required(manifest_path)
    for key in ("factorio_version", "seed", "start_world_tick"):
        require(manifest.get(key) == spec[key], f"Route manifest differs from baseline in {key}.")

    files = manifest.get("sha256")
    require(isinstance(files, dict) and len(files) > 0, "Route manifest lacks file hashes.")
    for name, expected in files.items():
        path = child_path(route, name)
        check_digest(path, expected, f"route file {name}")

    reference_path = child_path(baseline.parent, spec.get("reference_file"))
    check_digest(reference_path, spec.get("reference_sha256"), "reference snapshot")
    reference = read_required(reference_path)
    check_snapshot_identity(reference, spec)
    check_completion(reference, require_all=True)
    return spec, manifest, reference


def check_mod_directory(directory, manifest):
    mods = read_required(directory / "mods" / "mod-list.json").get("mods")
    require(isinstance(mods, list), "Invalid mod-list.json.")
    require(
        all(isinstance(mod, dict) and isinstance(mod.get("name"), str) and type(mod.get("enabled")) is bool for mod in mods),
        "Invalid mod entry in mod-list.json.",
    )
    require(len({mod["name"] for mod in mods}) == len(mods), "Duplicate entries in mod-list.json.")
    require({mod["name"] for mod in mods if mod["enabled"]} == EXPECTED_MODS, "Enabled mods differ from the base-game route.")

    mods_directory = (directory / "mods").resolve()
    for name, expected in manifest["sha256"].items():
        if name.startswith("mod/"):
            check_digest(child_path(mods_directory, name.removeprefix("mod/")), expected, f"run copy of {name}")

    timing = manifest["modes"]["headless"]
    expected_policy = (
        f"return {{speed={timing['speed']},horizon={timing['horizon_ticks']},"
        f"start_tick={manifest['start_world_tick']},visible=false,test_run=true}}\n"
    )
    policy = mods_directory / f"{ROUTE_MOD}_0.1.0" / "trial-policy.lua"
    try:
        actual_policy = policy.read_text(encoding="ascii")
    except (OSError, UnicodeDecodeError) as error:
        raise InvalidEvidence("Cannot read run trial-policy.lua.") from error
    require(actual_policy == expected_policy, "Run trial-policy.lua does not match the route manifest.")


def check_snapshot_identity(snapshot, spec):
    require(not snapshot.get("error"), "Factorio reported an error in its snapshot.")
    require(snapshot.get("base") == spec["factorio_version"], "Snapshot base game version differs.")
    require(snapshot.get("seed") == spec["seed"], "Snapshot seed differs.")
    elapsed_tick, world_tick = snapshot.get("tick"), snapshot.get("world_tick")
    require(type(elapsed_tick) is int and type(world_tick) is int and elapsed_tick >= 0, "Invalid snapshot ticks.")
    require(world_tick - elapsed_tick == spec["start_world_tick"], "Snapshot start tick differs.")


def check_completion(snapshot, *, require_all):
    events = snapshot.get("events")
    # Factorio encodes an empty Lua table as either an object or an array.
    if not require_all and events == []:
        return {}
    require(isinstance(events, dict), "Snapshot event ledger is invalid.")
    ticks = {}
    for name in EVENTS:
        if name not in events:
            continue
        event = events[name]
        require(isinstance(event, dict) and type(event.get("tick")) is int, f"Event {name} has no integer tick.")
        ticks[name] = event["tick"]

    ordered = list(ticks.values())
    require(
        all(0 <= tick <= snapshot["tick"] for tick in ordered)
        and all(before < after for before, after in zip(ordered, ordered[1:])),
        "Launch and delivery event order is invalid.",
    )
    if require_all:
        missing = [event for event in EVENTS if event not in ticks]
        require(not missing, "Missing event evidence for " + ", ".join(missing) + ".")
        require(ticks["delivery"] == snapshot["tick"], "Snapshot tick does not match the inventory confirmation.")
        require(
            type(events["cargo-pod-delivered"].get("value")) is int
            and events["cargo-pod-delivered"]["value"] == COUNTS["space_science"]
            and type(events["delivery"].get("value")) is int
            and events["delivery"]["value"] == COUNTS["space_science"],
            "Cargo and inventory events must each report 1,000 science packs.",
        )
        for resource, expected in COUNTS.items():
            require(type(snapshot.get(resource)) is int and snapshot[resource] == expected, f"Unexpected {resource} count.")
        for resource in ("produced", "consumed"):
            require(isinstance(snapshot.get(resource), dict) and bool(snapshot[resource]), f"Missing {resource} totals.")
    return ticks


def verify_engine_log(directory, spec, delivery_tick):
    try:
        log = (directory / "run.log").read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise InvalidEvidence("Cannot read Factorio run.log.") from error

    header = HEADER.search(log)
    require(header is not None, "Factorio version and build banner is missing.")
    version, build, attributes = header.groups()
    require(
        version == spec["factorio_version"] and int(build) == spec["factorio_build"]
        and "steam" in [part.strip() for part in attributes.split(",")],
        "Factorio version, build, or Steam edition differs.",
    )
    require("Running in headless mode" in log, "Factorio did not report headless mode.")
    passed = TEST_PASSED.search(log)
    require(
        passed is not None and int(passed.group(1)) == delivery_tick + 1,
        "Factorio did not report test completion one tick after the inventory confirmation.",
    )
    goodbye = GOODBYE.search(log, pos=passed.end())
    require(goodbye is not None, "Factorio shutdown evidence is missing.")
    return float(goodbye.group(1))


def verify(route, baseline, run_id, launcher_exit):
    if launcher_exit is not None:
        require(launcher_exit == 0, f"Launcher exited with code {launcher_exit}.")
    terminal = launcher_exit is not None

    spec, manifest, reference = read_reference(baseline, route)
    directory = route / "runs" / run_id
    metadata = read_live(directory / "run.json", terminal, "starting")
    for name in ("mode", "seed", "input_world_sha256"):
        require(metadata.get(name) == spec.get(name) and name in spec, f"Run metadata differs in {name}.")
    check_digest(directory / "input-world.zip", spec["input_world_sha256"], "starting save input-world.zip")
    check_mod_directory(directory, manifest)

    output = directory / "script-output"
    require(not (output / "opening-error.json").exists(), "Factorio reported an opening error.")
    started = (output / "opening-start.json").exists()
    snapshot = read_live(output / "through-latest.json", terminal, "running" if started else "starting")
    check_snapshot_identity(snapshot, spec)
    ticks = check_completion(snapshot, require_all=terminal)
    if not terminal:
        if "delivery" in ticks:
            raise PendingEvidence("incomplete", "Delivery exists. Waiting for launcher completion proof.")
        raise PendingEvidence("running", "Game snapshot is available. Waiting for delivery.")

    for field in ("tick", "world_tick", "events", "produced", "consumed"):
        require(snapshot[field] == reference[field], f"Snapshot {field} differs from the reference.")
    world_ticks = {name: tick + spec["start_world_tick"] for name, tick in ticks.items()}
    seconds = verify_engine_log(directory, spec, world_ticks["delivery"])
    return {
        "route_manifest_sha256": spec["route_manifest_sha256"],
        "input_world_sha256": spec["input_world_sha256"],
        "factorio_version": spec["factorio_version"],
        "factorio_build": spec["factorio_build"],
        "seed": spec["seed"],
        "world_ticks": world_ticks,
        "event_count": len(snapshot["events"]),
        "produced_count": len(snapshot["produced"]),
        "consumed_count": len(snapshot["consumed"]),
        "factorio_process_seconds": seconds,
        **{key: snapshot[key] for key in COUNTS},
    }


def run_name(value):
    reserved = r"CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]"
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,39}", value) or re.fullmatch(reserved, value, re.IGNORECASE):
        raise argparse.ArgumentTypeError("Use a valid run ID of 1–40 ASCII letters, digits, underscores, or hyphens.")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_id", type=run_name)
    parser.add_argument("--route", type=Path, required=True, help="Directory of the pinned runtime route.")
    parser.add_argument("--baseline", type=Path, required=True, help="Pinned baseline.json.")
    parser.add_argument("--engine-exit", type=int, help="Completed run_route.py launcher return code.")
    args = parser.parse_args()
    report = {"schema_version": 1, "run_id": args.run_id}
    try:
        evidence = verify(args.route.resolve(), args.baseline.resolve(), args.run_id, args.engine_exit)
    except PendingEvidence as error:
        report.update(state=error.state, reason=str(error))
        code = 2
    except InvalidEvidence as error:
        report.update(state="failed", reason=str(error))
        code = 1
    except (KeyError, TypeError, ValueError, OSError):
        report.update(state="failed", reason="Input or evidence could not be interpreted.")
        code = 1
    else:
        report.update(state="matched", reason="All process, input, event, and inventory evidence matches.", **evidence)
        code = 0
    print(json.dumps(report), flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())
