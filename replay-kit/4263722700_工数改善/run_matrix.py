"""Run the pinned Factorio route repeatedly and verify each finished run."""

import argparse
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess
import sys
import time
from uuid import uuid4


ROOT = Path(__file__).resolve().parent


def utc_time():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def seconds_since(start):
    return round(time.monotonic() - start, 3)


def file_hash(path):
    return sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def publish(result_dir, summary, message=None):
    target = result_dir / "summary.json"
    temporary = target.with_suffix(".tmp")
    temporary.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(target)
    if message is not None:
        print(message, flush=True)


def run_process(command, log_dir, name):
    start = time.monotonic()
    with (log_dir / f"{name}.stdout.txt").open("wb") as out, (log_dir / f"{name}.stderr.txt").open("wb") as err:
        # The route launcher owns the Factorio child and cleans it up on interruption.
        with subprocess.Popen(
            [sys.executable, "-X", "utf8", *map(str, command)],
            stdin=subprocess.DEVNULL,
            stdout=out,
            stderr=err,
        ) as process:
            try:
                code = process.wait()
            except KeyboardInterrupt:
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    process.wait()
                raise
    return code, seconds_since(start)


def factorio_wall_time(path):
    if not path.is_file():
        return None
    match = re.search(r"^\s*(\d+(?:\.\d+)?)\s+Goodbye\s*$", path.read_text(encoding="utf-8", errors="replace"), re.MULTILINE)
    return float(match.group(1)) if match else None


def check_pins(route, baseline_path):
    baseline = read_json(baseline_path)
    if baseline["schema_version"] != 1 or baseline["mode"] != "headless":
        raise ValueError("The matrix requires a headless baseline with schema version 1.")
    if file_hash(route / "manifest.json") != baseline["route_manifest_sha256"]:
        raise ValueError("The route manifest does not match the pinned baseline.")
    reference = (baseline_path.parent / baseline["reference_file"]).resolve()
    if not reference.is_relative_to(baseline_path.parent):
        raise ValueError("The baseline reference must be inside the baseline directory.")
    if file_hash(reference) != baseline["reference_sha256"]:
        raise ValueError("The reference evidence does not match the pinned baseline.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--route", type=Path, default=ROOT / "基準ルート")
    parser.add_argument("--baseline", type=Path, default=ROOT / "baseline.json")
    parser.add_argument("--count", type=int, default=3, help="Number of consecutive fresh runs (default: 3).")
    parser.add_argument("--id", help="New result directory name and run ID prefix.")
    parser.add_argument("--factorio", type=Path, help="Optional Windows Factorio executable.")
    parser.add_argument("--timeout", type=int, default=1800, help="Headless timeout per run in real seconds.")
    args = parser.parse_args(argv)
    if not 1 <= args.count <= 999:
        parser.error("--count must be between 1 and 999.")
    if args.timeout < 1:
        parser.error("--timeout must be positive.")
    matrix_id = args.id
    if matrix_id is None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        matrix_id = f"repro-{stamp}-{uuid4().hex[:6]}"
    elif not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,35}", matrix_id):
        parser.error("--id must be 1–36 ASCII letters, digits, underscores or hyphens.")
    elif re.fullmatch(r"CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]", matrix_id, flags=re.IGNORECASE):
        parser.error("--id is a reserved directory name on Windows.")

    route = args.route.expanduser().resolve()
    baseline = args.baseline.expanduser().resolve()
    launcher = route / "run_route.py"
    verifier = ROOT / "verify_run.py"
    factorio = ["--factorio", args.factorio.expanduser().resolve()] if args.factorio else []
    run_ids = [f"{matrix_id}-{index:03d}" for index in range(1, args.count + 1)]
    result_dir = ROOT / "results" / matrix_id
    result_dir.parent.mkdir(exist_ok=True)
    try:
        result_dir.mkdir()
    except FileExistsError:
        parser.error("That matrix already has a result directory. Choose a new ID.")

    start = time.monotonic()
    summary = {
        "schema_version": 1,
        "matrix_id": matrix_id,
        "mode": "headless",
        "started_utc": utc_time(),
        "state": "preflight",
        "requested_runs": args.count,
        "planned_run_ids": run_ids,
        "matched_runs": 0,
        "cases": [],
    }
    publish(result_dir, summary, f"{matrix_id}: preflight")
    exit_code = 1
    active = None
    try:
        check_pins(route, baseline)
        summary["baseline_sha256"] = file_hash(baseline)
        if not launcher.is_file() or not verifier.is_file():
            raise ValueError("The route launcher or verifier is missing.")
        if any((route / "runs" / run_id).exists() for run_id in run_ids):
            raise ValueError("A planned run ID already exists in the selected route.")
        code, wall = run_process([launcher, "check", *factorio], result_dir, "preflight")
        summary["preflight"] = {"returncode": code, "wall_seconds": wall}
        if code != 0:
            raise RuntimeError("Route preflight failed. See preflight.stderr.txt.")

        summary["state"] = "running"
        for index, run_id in enumerate(run_ids, start=1):
            active = {"run_id": run_id, "state": "launching", "started_utc": utc_time()}
            summary["cases"].append(active)
            logs = result_dir / run_id
            logs.mkdir()
            publish(result_dir, summary, f"{matrix_id}: run {index}/{args.count} | {run_id}")

            code, wall = run_process(
                [launcher, "headless", run_id, *factorio, "--timeout", args.timeout],
                logs,
                "launcher",
            )
            run_dir = route / "runs" / run_id
            active.update(
                launcher_returncode=code,
                launcher_wall_seconds=wall,
                world_generation_process_seconds=factorio_wall_time(run_dir / "world-generation.log"),
                factorio_process_seconds=factorio_wall_time(run_dir / "run.log"),
                state="verifying",
            )
            publish(result_dir, summary)
            verified, wall = run_process(
                [verifier, "--route", route, "--baseline", baseline, run_id, "--engine-exit", code],
                logs,
                "verifier",
            )
            active.update(verifier_returncode=verified, verifier_wall_seconds=wall)
            try:
                proof = read_json(logs / "verifier.stdout.txt")
            except (ValueError, UnicodeError):
                proof = None
            if isinstance(proof, dict):
                active["verification"] = proof
            if code != 0 or verified != 0 or not isinstance(proof, dict) or proof.get("state") != "matched":
                raise RuntimeError(f"{run_id} did not match the baseline. See its launcher and verifier logs.")

            active.update(state="matched", finished_utc=utc_time())
            summary["matched_runs"] += 1
            publish(result_dir, summary, f"{run_id}: matched")
            active = None

        summary["state"] = "matched"
        exit_code = 0
    except KeyboardInterrupt:
        summary.update(state="interrupted", reason="Interrupted by the operator.")
        if active is not None:
            active.update(state="interrupted", finished_utc=utc_time())
        exit_code = 130
    except (OSError, KeyError, TypeError, ValueError, RuntimeError) as error:
        summary.update(state="failed", reason=str(error))
        if active is not None:
            active.update(state="failed", finished_utc=utc_time())
    finally:
        summary.update(finished_utc=utc_time(), wall_seconds=seconds_since(start))
        publish(result_dir, summary, f"{matrix_id}: {summary['state']} ({summary['matched_runs']}/{args.count})")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
