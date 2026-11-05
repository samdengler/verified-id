#!/usr/bin/env python3
"""Run every request of build/one-id-data/decisions.jsonl and
build/one-id-data/presentation/decisions.jsonl through lake exe oracle and
compare each answer with the recorded response.

lake exe oneid-facts already checks, inside Lean, that the oracle's handler
answers each request as the model's functions do.  This runs the executable a
team would run, through standard input and output, so a fault in reading or
writing lines shows up too.  It fails on the first line whose answer differs,
naming it.

  python3 scripts/replay_one_id.py
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "build" / "one-id-data"
FILES = [DATA / "decisions.jsonl", DATA / "presentation" / "decisions.jsonl"]


def main():
    for f in FILES:
        if not f.exists():
            sys.exit(f"replay_one_id: {f.relative_to(ROOT)} is missing; run: lake exe oneid-facts")
    lines = [(f, json.loads(line)) for f in FILES for line in f.read_text().splitlines() if line.strip()]
    requests = "".join(json.dumps(d["request"], ensure_ascii=False) + "\n" for _, d in lines)
    run = subprocess.run(["lake", "exe", "oracle"], cwd=ROOT, input=requests, capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit(f"replay_one_id: lake exe oracle failed:\n{run.stderr}")
    answers = [json.loads(a) for a in run.stdout.splitlines()]
    if len(answers) != len(lines):
        sys.exit(f"replay_one_id: {len(lines)} requests and {len(answers)} answers")
    for (f, d), a in zip(lines, answers):
        if a != d["response"]:
            sys.exit(f"replay_one_id: {f.relative_to(ROOT)}: {d['name']}: the oracle answers {json.dumps(a)}, "
                     f"and the file records {json.dumps(d['response'])}")
    counts = ", ".join(f"{sum(1 for g, _ in lines if g == f)} from {f.relative_to(DATA)}" for f in FILES)
    print(f"replayed {len(lines)} decisions through lake exe oracle ({counts}): every answer matches")


if __name__ == "__main__":
    main()
