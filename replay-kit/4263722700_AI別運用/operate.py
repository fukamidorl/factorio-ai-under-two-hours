"""Run or inspect one pinned Factorio replay with a small JSON interface."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess
import sys


HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent / "4263722700_工数改善"
ROUTE = PACKAGE / "基準ルート"
RUN_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,35}")
RESERVED = re.compile(r"CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]", re.IGNORECASE)
EXIT_STATUS = {"matched": 0, "failed": 1, "starting": 2, "running": 2, "incomplete": 2}
TIMING_FIELDS = (
    "world_generation_process_seconds", "factorio_process_seconds",
    "launcher_wall_seconds", "verifier_wall_seconds",
)
EVENTS = ("launch-ordered", "launch", "cargo-pod-delivered", "delivery")
AMOUNTS = {"rockets": 1, "satellites": 1, "space_science": 1000, "silo_parts": 0}


def valid_run_id(value):
    if RUN_ID.fullmatch(value) and not RESERVED.fullmatch(value):
        return value
    raise argparse.ArgumentTypeError("Use 1–36 ASCII letters, digits, underscores or hyphens.")


def read_json(path):
    value = json.loads(path.read_bytes())
    if not isinstance(value, dict):
        raise ValueError("Expected a JSON object.")
    return value


def describe(run_id, state, reason, **details):
    return {"schema_version": 1, "id": run_id, "state": state, "reason": reason, **details}


def time_at(ticks):
    total_millis = round(ticks * 1000 / 60)
    seconds, millis = divmod(total_millis, 1000)
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours}:{minutes:02}:{seconds:02}.{millis:03}"


def reason_for_failure(summary):
    reason = summary.get("reason", "")
    if not isinstance(reason, str):
        return "matrix_failed"
    reason = reason.lower()
    cases = summary.get("cases")
    if isinstance(cases, list) and len(cases) == 1 and isinstance(cases[0], dict):
        receipt = cases[0].get("verification")
        if isinstance(receipt, dict) and isinstance(receipt.get("reason"), str):
            verification_reason = receipt["reason"].lower()
            if "starting save" in verification_reason or "input_world_sha256" in verification_reason:
                return "initial_world_mismatch"
            if "version, build, or steam" in verification_reason:
                return "factorio_build_mismatch"
    if "manifest" in reason or "reference evidence" in reason:
        return "pinned_input_mismatch"
    if "preflight" in reason:
        return "preflight_failed"
    if summary.get("state") == "interrupted":
        return "interrupted"
    return "matrix_failed"


def file_hash(path):
    return sha256(path.read_bytes()).hexdigest()


def verified_result(run_id, folder, summary, case):
    if summary.get("matched_runs") != 1 or not summary.get("finished_utc") or case.get("state") != "matched":
        return describe(run_id, "incomplete", "missing_completion_receipt")
    if case.get("launcher_returncode") != 0 or case.get("verifier_returncode") != 0:
        return describe(run_id, "failed", "process_or_verification_failed")
    try:
        pins = read_json(PACKAGE / "baseline.json")
        reference = (PACKAGE / pins["reference_file"]).resolve()
        if not reference.is_relative_to(PACKAGE):
            raise ValueError("Reference is outside the package.")
        if file_hash(PACKAGE / "baseline.json") != summary.get("baseline_sha256"):
            return describe(run_id, "failed", "pinned_input_mismatch")
        if file_hash(reference) != pins["reference_sha256"]:
            return describe(run_id, "failed", "pinned_input_mismatch")
        expected = read_json(reference)
        archived = read_json(folder / case["run_id"] / "verifier.stdout.txt")
        proof = case["verification"]
        events = proof["world_ticks"]
        expected_ticks = {
            key: expected["events"][key]["tick"] + pins["start_world_tick"]
            for key in EVENTS
        }
        identities = ("factorio_version", "factorio_build", "seed", "route_manifest_sha256", "input_world_sha256")
        agreed = all(proof.get(key) == pins[key] for key in identities)
        arrived = all(proof.get(key) == quantity for key, quantity in AMOUNTS.items())
        if (
            proof != archived or proof.get("state") != "matched" or proof.get("run_id") != case["run_id"]
            or not agreed or not arrived or not all(events.get(key) == tick for key, tick in expected_ticks.items())
        ):
            return describe(run_id, "incomplete", "unconfirmed_arrival")
    except (OSError, KeyError, TypeError, ValueError):
        return describe(run_id, "incomplete", "unreadable_completion_evidence")

    tick = expected_ticks["delivery"]
    return describe(
        run_id, "matched", "verified",
        completed=True, mode="headless", factorio_version=pins["factorio_version"],
        factorio_build=pins["factorio_build"], seed=pins["seed"],
        input_hash_match=True, route_manifest_match=True, verified_event_count=proof.get("event_count"),
        delivery_world_tick=tick, delivery_world_time=time_at(tick),
        rockets=proof["rockets"], satellites=proof["satellites"], silo_parts=proof["silo_parts"],
        landing_pad_space_science=proof["space_science"], events=expected_ticks,
        timing_s={field: case.get(field) for field in TIMING_FIELDS},
        matrix_wall_seconds=summary.get("wall_seconds"),
    )


def status(run_id):
    folder = PACKAGE / "results" / run_id
    try:
        summary = read_json(folder / "summary.json")
    except FileNotFoundError:
        return describe(run_id, "incomplete", "result_not_found")
    except (OSError, ValueError):
        return describe(run_id, "incomplete", "unreadable_summary")
    if (
        summary.get("schema_version") != 1 or summary.get("matrix_id") != run_id
        or summary.get("mode") != "headless" or summary.get("requested_runs") != 1
    ):
        return describe(run_id, "incomplete", "unexpected_summary")
    state = summary.get("state")
    if state in ("failed", "interrupted"):
        return describe(run_id, "failed", reason_for_failure(summary))
    if state == "preflight":
        return describe(run_id, "starting", "launcher_preflight")
    cases = summary.get("cases")
    if isinstance(cases, list) and not cases and state == "running":
        return describe(run_id, "starting", "awaiting_first_run")
    if not isinstance(cases, list) or len(cases) != 1 or not isinstance(cases[0], dict):
        return describe(run_id, "incomplete", "missing_single_run")
    case = cases[0]
    if case.get("run_id") != f"{run_id}-001":
        return describe(run_id, "incomplete", "unexpected_run_id")
    if state == "matched":
        return verified_result(run_id, folder, summary, case)
    if state == "running":
        progress = {}
        try:
            latest = read_json(ROUTE / "runs" / case["run_id"] / "script-output" / "through-latest.json")
            if type(latest.get("world_tick")) is int:
                progress["last_world_tick"] = latest["world_tick"]
            if isinstance(latest.get("research"), str):
                progress["research"] = latest["research"]
        except (OSError, ValueError):
            pass
        stage = case.get("state")
        return describe(run_id, "running", "verifying" if stage in ("verifying", "matched") else "awaiting_delivery", **progress)
    return describe(run_id, "incomplete", "unknown_matrix_state")


def replay(run_id, factorio):
    if (PACKAGE / "results" / run_id).exists():
        return describe(run_id, "failed", "id_already_used")
    command = [
        sys.executable, "-B", "-X", "utf8", str(PACKAGE / "run_matrix.py"),
        "--id", run_id, "--count", "1",
    ]
    if factorio is not None:
        command.extend(("--factorio", str(factorio.resolve())))
    try:
        execution = subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True, cwd=PACKAGE, check=False)
    except KeyboardInterrupt:
        return describe(run_id, "failed", "interrupted")
    except OSError:
        return describe(run_id, "failed", "cannot_start_matrix")
    result = status(run_id)
    if execution.returncode != 0 and result["state"] not in ("failed", "incomplete"):
        return describe(run_id, "failed", "matrix_process_failed")
    return result


def practice():
    data = read_json(HERE / "practice_cases.json")
    if data.get("schema_version") != 1 or len(data["cases"]) != 4:
        raise ValueError("Unexpected practice fixture format.")
    return {"schema_version": 1, "cases": [
        {"id": case["id"], "status": case["status"]} for case in data["cases"]
    ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser("replay", help="Create a fresh run and wait for verification.")
    start.add_argument("--id", type=valid_run_id, required=True)
    start.add_argument("--factorio", type=Path, help="Optional local Factorio executable.")
    read = commands.add_parser("status", help="Inspect the result of a single replay.")
    read.add_argument("--id", type=valid_run_id, required=True)
    commands.add_parser("practice", help="Print a synthetic, ungraded four-case exercise.")
    args = parser.parse_args()
    if args.command == "practice":
        try:
            result = practice()
        except (OSError, ValueError, TypeError, KeyError):
            print(json.dumps({"schema_version": 1, "state": "failed", "reason": "invalid_practice_fixture"}))
            return 1
        print(json.dumps(result, ensure_ascii=True))
        return 0
    result = replay(args.id, args.factorio) if args.command == "replay" else status(args.id)
    print(json.dumps(result, ensure_ascii=True))
    return EXIT_STATUS[result["state"]]


if __name__ == "__main__":
    sys.exit(main())
