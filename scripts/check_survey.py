#!/usr/bin/env python3
"""Check that the survey, the blueprint, the model and the citations agree.

  python3 scripts/check_survey.py

Run by scripts/build-site.sh after `lake exe status`.  It fails when:

  - a survey entry has neither a blueprint node nor a requirement in the model;
  - a blueprint candidate is missing from the survey;
  - an entry the survey grades vague or silent is not marked \\notready in the
    blueprint, or a clear one is;
  - a vague or silent entry has no open point;
  - the counts in the survey's table differ from its rows;
  - the survey, the blueprint or a source key cites a section the guide does
    not have (sources/outline.json).

The survey and the blueprint are both written by hand, so this is what keeps
them from drifting apart.
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_progress import parse_nodes  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SURVEY = ROOT / "docs" / "one-id-survey.md"
OUTLINE = ROOT / "sources" / "outline.json"
STATUS = ROOT / "build" / "status.json"
GRADES = ["Clear", "Vague", "Silent"]
ROW = re.compile(r"^\| ((?:C|G)-\d+) \|(.*)\|\s*$")
# §4.2.1.2 and "Annex A" / "Annex B".
SECTION = re.compile(r"§(\d+(?:\.\d+)*)")
ANNEX = {"Annex A": "5", "Annex B": "6"}


def survey_rows():
    rows = {}
    for line in SURVEY.read_text().splitlines():
        m = ROW.match(line)
        if not m:
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", m.group(2))]
        if len(cells) != 8:
            continue  # the table of blocked guarantees repeats the IDs with other columns
        rule, level, kind, grade, shows, point, model, source = cells
        if m.group(1) in rows:
            sys.exit(f"survey: {m.group(1)} is listed twice")
        rows[m.group(1)] = {"rule": rule, "level": level, "kind": kind, "grade": grade, "open": point,
                            "model": model, "source": source}
    return rows


def stated_counts():
    """The counts in the survey's own table, under "## Counts"."""
    text = SURVEY.read_text().split("## Counts", 1)[1].split("## ", 1)[0]
    return {g: int(n) for g, n in re.findall(r"^\| (Clear|Vague|Silent|Total) \| (\d+) \|", text, re.M)}


def cited(text):
    out = set(SECTION.findall(text))
    out |= {number for name, number in ANNEX.items() if name in text}
    return out


def main():
    errors = []
    rows = survey_rows()
    nodes = parse_nodes()
    by_id = {n["cid"]: n for n in nodes if n["cid"]}
    status = json.loads(STATUS.read_text())
    requirements = {d["earsId"] for d in status["declarations"] if d.get("earsId")}
    sections = {s["number"] for s in json.loads(OUTLINE.read_text())["sections"]}

    for cid, r in rows.items():
        models = [m.strip() for m in r["model"].split(",") if m.strip().startswith("OID-")]
        if r["grade"] not in GRADES:
            errors.append(f"{cid}: the grade is {r['grade']!r}, not one of {', '.join(GRADES)}")
        if models:
            for m in models:
                if m not in requirements:
                    errors.append(f"{cid}: the survey names requirement {m}, which the model does not have")
        elif cid not in by_id:
            errors.append(f"{cid}: no blueprint node and no requirement in the model")
        node = by_id.get(cid)
        if node and not node["lean"] and node["env"] == "definition":
            undecided = r["grade"] in ("Vague", "Silent")
            if undecided != node["notready"]:
                errors.append(f"{cid}: the survey says {r['grade']} and the blueprint node is "
                              f"{'marked' if node['notready'] else 'not marked'} \\notready")
        if r["grade"] in ("Vague", "Silent") and not r["open"]:
            errors.append(f"{cid}: graded {r['grade']} with no open point")
        for number in cited(r["source"]):
            if number not in sections:
                errors.append(f"{cid}: cites §{number}, which the guide's outline does not have")
    for cid in by_id:
        if cid not in rows:
            errors.append(f"{cid}: a blueprint node with no survey entry")

    rules = [r for cid, r in rows.items() if cid.startswith("C-")]
    counts = Counter(r["grade"] for r in rules)
    stated = stated_counts()
    for g in GRADES:
        if stated.get(g) != counts[g]:
            errors.append(f"the survey's table says {stated.get(g)} {g.lower()} entries; its rows have {counts[g]}")
    if stated.get("Total") != len(rules):
        errors.append(f"the survey's table says {stated.get('Total')} entries in total; its rows have {len(rules)}")

    for n in nodes:
        for p in n["paras"]:
            if p.startswith(("Source:", "Sources:")):
                for number in cited(p):
                    if number not in sections:
                        errors.append(f"blueprint node {n['label']}: cites §{number}, which the guide's outline does not have")
    for s in status["sources"]:
        for number in cited(s["title"]):
            if number not in sections:
                errors.append(f"source key {s['key']}: cites §{number}, which the guide's outline does not have")

    if errors:
        sys.exit("survey check failed:\n  " + "\n  ".join(errors))
    in_model = sum(1 for r in rules if "OID-" in r["model"])
    print(f"survey: {len(rules)} entries ({counts['Clear']} clear, {counts['Vague']} vague, {counts['Silent']} silent), "
          f"{in_model} in the model, {len(rules) - in_model} candidates; {len(rows) - len(rules)} candidate guarantees; "
          f"every citation is a section of the guide")


if __name__ == "__main__":
    main()
