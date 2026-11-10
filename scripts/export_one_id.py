#!/usr/bin/env python3
"""Write build/one-id-data/model.json, the part of the model a product site
reads beside the scenarios, readings and decisions that lake exe oneid-facts
writes to the same directory.

The shape follows verified-air's scripts/export_airline.py, so a site that
shows that model's requirements can show these the same way:

  * source: the commit the files were built from, and whether the working
    tree had changes that commit does not hold;
  * requirements: every requirement, with its Lean name, its EARS statement in
    Kiro's notation, and its criteria with their statuses;
  * openQuestions: for each criterion an open theorem checks, those theorems,
    each with the start of its question and its example.

It differs from verified-air's in five ways.  Every "review" is null, since
the export does not yet compute addresses in the review document.
source.dirty says whether the working tree had changes at build time.  Each open question also names its
example, the first @[case] its docstring quotes.  identifiers holds the
document types, namespaces and data element identifiers with their values,
from build/one-id-identifiers.json (lake exe oneid-facts), so no identifier is
typed by hand.  There is no theorems.json, since the scenarios have no facts
proven for every input.

  python3 scripts/export_one_id.py
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_status import kiro_ears  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "build" / "status.json"
IDENTIFIERS = ROOT / "build" / "one-id-identifiers.json"
OUT = ROOT / "build" / "one-id-data"
REPO = "https://github.com/samdengler/verified-id"
# CI publishes site/ here through GitHub Pages (.github/workflows/ci.yml).
SITE = "https://samdengler.github.io/verified-id/"


def plain(s):
    """A docstring as status.json holds it, Markdown rendered from Verso, as
    plain text: the backslash before escaped punctuation dropped, names left
    in backticks."""
    return re.sub(r"\\([!-/:-@\[-`{-~])", r"\1", s)


def opening(docstring):
    """The start of an open theorem's question: its first sentence or two after
    the words "Open question for ...", with names still in backticks."""
    text = plain(docstring)
    m = re.search(r"Open question for [^.]*\.\s*(.*)", text, re.S)
    if not m:
        return ""
    body = " ".join(m.group(1).split())
    sentences = re.split(r"(?<=[.?])\s+(?=[A-Z])", body)
    # The first sentence, and the second too if both are short.
    n = 2 if len(sentences) > 1 and len(sentences[0]) + len(sentences[1]) < 220 else 1
    return " ".join(sentences[:n]) + (" …" if len(sentences) > n else "")


def example_of(docstring, cases):
    """The first @[case] example a docstring quotes, by its Lean name."""
    for name in re.findall(r"`([^`]+)`", docstring):
        for full in (name, "Rules.OneId." + name):
            if full in cases:
                return full
    return None


def commit():
    if os.environ.get("GITHUB_SHA"):
        return os.environ["GITHUB_SHA"]
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def dirty():
    """Whether the working tree differs from the commit: `git status
    --porcelain` prints anything.  None when git cannot tell."""
    try:
        out = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True,
                             check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return out.strip() != ""


def main():
    if not STATUS.exists():
        sys.exit("export_one_id: build/status.json is missing; run: lake exe status")
    if not IDENTIFIERS.exists():
        sys.exit("export_one_id: build/one-id-identifiers.json is missing; run: lake exe oneid-facts")
    decls = json.loads(STATUS.read_text())["declarations"]
    cases = {d["name"] for d in decls if d["kind"] == "case"}
    requirements = {}
    for d in sorted((d for d in decls if d.get("earsId")), key=lambda d: d["earsId"]):
        requirements[d["earsId"]] = {
            "name": d["name"],
            "ears": kiro_ears(plain(d["ears"])),
            "review": None,
            "criteria": [{"id": c["id"], "status": c["status"], "ears": kiro_ears(plain(c["ears"]))}
                         for c in d["criteria"]],
        }
    questions = {}
    for d in sorted((d for d in decls if d["kind"] == "theorem" and d["status"] == "open"), key=lambda d: d["name"]):
        for c in d.get("checks", []):
            questions.setdefault(c, []).append(
                {"theorem": d["name"], "question": opening(d["docstring"]),
                 "example": example_of(d["docstring"], cases), "review": None})
    for c, qs in questions.items():
        for q in qs:
            if not q["question"]:
                sys.exit(f"export_one_id: {q['theorem']} is open and its docstring has no 'Open question for' paragraph")
    model = {
        "source": {"repository": REPO, "commit": commit(), "dirty": dirty(), "site": SITE},
        "identifiers": json.loads(IDENTIFIERS.read_text())["identifiers"],
        "requirements": requirements,
        "openQuestions": dict(sorted(questions.items())),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "model.json").write_text(json.dumps(model, indent=1, ensure_ascii=False) + "\n")
    print(f"wrote build/one-id-data/model.json: {len(requirements)} requirements, "
          f"{len(questions)} criteria with open questions")


if __name__ == "__main__":
    main()
