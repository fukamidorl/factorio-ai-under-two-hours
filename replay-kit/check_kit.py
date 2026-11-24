"""Verify the replay files, manual launch save, and installed Steam Factorio build."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parent
DEFAULT_FACTORIO = Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe")
EXPECTED_VERSION = "2.1.25"
EXPECTED_BUILD = 88022
EXPECTED_SEED = 4263722700
VERSION_LINE = re.compile(r"^Version:\s+(\d+\.\d+\.\d+) \(build (\d+), ([^\r\n)]+)\)\s*$", re.MULTILINE)


def read_json(path):
    return json.loads(path.read_bytes())


def checked_hash(root, relative, expected):
    path = (root / relative).resolve()
    if not path.is_relative_to(root):
        raise ValueError(f"Path is outside the kit directory: {relative}")
    if sha256(path.read_bytes()).hexdigest() != expected:
        raise ValueError(f"Checksum mismatch: {relative}")
    return path


def check_route(route, expected_manifest_hash):
    manifest = checked_hash(route, "manifest.json", expected_manifest_hash)
    data = read_json(manifest)
    if (data["factorio_version"], data["seed"]) != (EXPECTED_VERSION, EXPECTED_SEED):
        raise ValueError(f"Unexpected version or seed in {route.name}/manifest.json")
    for name, checksum in data["sha256"].items():
        checked_hash(route, name, checksum)
    return len(data["sha256"])


def check_files():
    core = ROOT / "4263722700_工数改善"
    baseline = read_json(core / "baseline.json")
    checked_hash(core, baseline["reference_file"], baseline["reference_sha256"])
    headless_count = check_route(core / "基準ルート", baseline["route_manifest_sha256"])
    delivery = read_json(ROOT / "evidence" / "visible-delivery-report.json")
    visible_count = check_route(ROOT / "画面付き走行", delivery["visible_manifest_sha256"])
    handoff = read_json(ROOT / "evidence" / "neutral-manual-handoff.json")
    save = checked_hash(ROOT, handoff["save_relative_to_kit"], handoff["save_sha256"])
    return headless_count, visible_count, save.relative_to(ROOT).as_posix()


def verify_engine_version(output):
    match = VERSION_LINE.search(output)
    if match is None:
        raise ValueError("Could not read the Factorio build from --version.")
    version, build, build_flags = match.groups()
    tags = {flag.strip().lower() for flag in build_flags.split(",")}
    if (version, int(build)) != (EXPECTED_VERSION, EXPECTED_BUILD) or not {"win64", "steam"} <= tags:
        raise ValueError(f"Expected Windows Steam Factorio {EXPECTED_VERSION} build {EXPECTED_BUILD}.")


def check_engine(executable):
    result = subprocess.run(
        [str(executable.resolve(strict=True)), "--version"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=True,
        timeout=15,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    verify_engine_version(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", type=Path, default=DEFAULT_FACTORIO,
                        help="Override the default Steam Factorio executable path.")
    args = parser.parse_args()
    try:
        headless_count, visible_count, save = check_files()
        check_engine(args.factorio)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps({"state": "failed", "reason": str(error)}, ensure_ascii=True))
        return 1
    print(json.dumps({
        "state": "ready",
        "factorio_version": EXPECTED_VERSION,
        "factorio_build": EXPECTED_BUILD,
        "distribution": "Steam",
        "seed": EXPECTED_SEED,
        "headless_files_checked": headless_count,
        "visible_files_checked": visible_count,
        "manual_checkpoint_checked": save,
    }, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
