#!/usr/bin/env python3
"""Run every request of build/one-id-data/decisions.jsonl through
lake exe oracle and compare each answer with the recorded response.

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
DECISIONS = ROOT / "build" / "one-id-data" / "decisions.jsonl"


def main():
    if not DECISIONS.exists():
        sys.exit("replay_one_id: build/one-id-data/decisions.jsonl is missing; run: lake exe oneid-facts")
    lines = [json.loads(line) for line in DECISIONS.read_text().splitlines() if line.strip()]
    requests = "".join(json.dumps(d["request"], ensure_ascii=False) + "\n" for d in lines)
    run = subprocess.run(["lake", "exe", "oracle"], cwd=ROOT, input=requests, capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit(f"replay_one_id: lake exe oracle failed:\n{run.stderr}")
    answers = [json.loads(a) for a in run.stdout.splitlines()]
    if len(answers) != len(lines):
        sys.exit(f"replay_one_id: {len(lines)} requests and {len(answers)} answers")
    for d, a in zip(lines, answers):
        if a != d["response"]:
            sys.exit(f"replay_one_id: {d['name']}: the oracle answers {json.dumps(a)}, "
                     f"and decisions.jsonl records {json.dumps(d['response'])}")
    print(f"replayed {len(lines)} decisions through lake exe oracle: every answer matches")


if __name__ == "__main__":
    main()
