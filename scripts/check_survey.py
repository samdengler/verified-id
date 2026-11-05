#!/usr/bin/env python3
"""Check that the survey, the blueprint, the model and the citations agree.

  python3 scripts/check_survey.py

Run by scripts/build-site.sh after `lake exe status`.  It fails when:

  - a survey entry has neither a blueprint node nor a requirement in the model;
  - a blueprint candidate is missing from the survey;
  - an entry the survey grades vague or silent is not marked \\notready in the
    blueprint, or a clear one is;
  - a vague or silent entry has no open point;
  - the survey names a clause that would settle an entry and its blueprint
    node has no Lookup: paragraph, or the other way round;
  - the counts in the survey's table differ from its rows;
  - the survey, the blueprint or a source key cites a section the guide does
    not have (sources/outline.json);
  - docs/external-survey.md, the survey, the blueprint or an assumption that
    was read cites a clause that the fetched copy of the specification does
    not have (sources/external.json);
  - an assumption is marked read and no fetched document covers it, or the
    other way round;
  - the table of documents in docs/external-survey.md differs from
    sources/external.json.

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
EXTERNAL = ROOT / "sources" / "external.json"
EXTERNAL_SURVEY = ROOT / "docs" / "external-survey.md"
BLUEPRINT = ROOT / "blueprint" / "src"
# A clause of an external specification: §5.2, §A.3.2, §B.2.6.2.
CLAUSE = re.compile(r"§((?:[A-Z]|\d+)(?:\.\d+)*)")
CLAUSES = r"((?:\s*(?:,|;|and|to)?\s*§(?:[A-Z]|\d+)(?:\.\d+)*)+)"
# How prose outside the external survey names a document before its clauses.
NAMED = [
    (re.compile(r"OpenID4VP(?:\s+1\.0)?" + CLAUSES), "openid4vp"),
    (re.compile(r"HAIP(?:\s+1\.0)?" + CLAUSES), "haip"),
    (re.compile(r"BCBP\s+(?:guide|Implementation\s+Guide,\s+seventh\s+edition,)" + CLAUSES), "iata-bcbp-guide"),
    (re.compile(r"RFC\s+(\d{4})" + CLAUSES), None),
]
VERDICTS = ("Agrees", "Adds", "Differs")


def survey_rows():
    rows = {}
    for line in SURVEY.read_text().splitlines():
        m = ROW.match(line)
        if not m:
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", m.group(2))]
        if len(cells) != 9:
            continue  # the table of blocked guarantees repeats the IDs with other columns
        rule, level, kind, grade, shows, point, lookup, model, source = cells
        if m.group(1) in rows:
            sys.exit(f"survey: {m.group(1)} is listed twice")
        rows[m.group(1)] = {"rule": rule, "level": level, "kind": kind, "grade": grade, "open": point,
                            "lookup": lookup, "model": model, "source": source}
    return rows


def stated_counts():
    """The counts in the survey's own table, under "## Counts"."""
    text = SURVEY.read_text().split("## Counts", 1)[1].split("## ", 1)[0]
    return {g: int(n) for g, n in re.findall(r"^\| (Clear|Vague|Silent|Total) \| (\d+) \|", text, re.M)}


def cited(text):
    out = set(SECTION.findall(text))
    out |= {number for name, number in ANNEX.items() if name in text}
    return out


def named_clauses(text):
    """(document, clause) for each clause prose cites after naming its document."""
    out = []
    for pattern, doc in NAMED:
        for m in pattern.finditer(text):
            name = doc or "rfc" + m.group(1)
            out += [(name, c) for c in CLAUSE.findall(m.group(m.lastindex))]
    return out


def check_external(status, errors):
    """The external survey, the read assumptions and every named clause, against the fetched outlines."""
    docs = {d["name"]: d for d in json.loads(EXTERNAL.read_text())["documents"]}
    have = {name: {x["number"] for x in d["sections"]} for name, d in docs.items()}

    def check(where, name, clause):
        if name not in have:
            errors.append(f"{where}: cites {name}, which sources/external.json does not record")
        elif clause not in have[name]:
            errors.append(f"{where}: cites §{clause} of {name}, which the fetched copy does not have")

    # Assumptions: read status agrees with the fetched documents, and cited clauses exist.
    covered = {k for d in docs.values() for k in d["assumptions"]}
    for a in status["assumptions"]:
        if a["read"]:
            doc = docs.get(a["document"])
            if not doc or a["key"] not in doc["assumptions"]:
                errors.append(f"assumption {a['key']}: marked read from {a['document']!r}, and "
                              "scripts/external_sources.py does not list it under that document")
                continue
            for c in CLAUSE.findall(a["clause"] + " " + a["statement"]):
                check(f"assumption {a['key']}", a["document"], c)
        elif a["key"] in covered:
            errors.append(f"assumption {a['key']}: a fetched document covers it and it is marked not read")

    # The external survey.
    text = EXTERNAL_SURVEY.read_text()
    listed, current, cited_rows = set(), [], 0
    for line in text.splitlines():
        m = re.match(r"^Documents?: (.*)$", line)
        if m:
            current = re.findall(r"`([^`]+)`", m.group(1))
            continue
        if line.startswith("## "):
            current = []
        if not line.startswith("| ") or set(line) <= set("|- "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 4 and cells[0].startswith("`"):
            key = cells[0].strip("`")
            listed.add(key)
            d = docs.get(key)
            if not d:
                errors.append(f"external survey: lists {key}, which sources/external.json does not record")
            elif cells[3] != ", ".join(d["version_printed"]) or cells[2] != d["guide_names"]:
                errors.append(f"external survey: the row for {key} differs from sources/external.json")
        elif len(cells) == 5 and current and cells[0] != "Clause":
            cited_rows += 1
            if not cells[4].startswith(VERDICTS):
                errors.append(f"external survey: the verdict {cells[4][:30]!r} is not one of {', '.join(VERDICTS)}")
            rfc = re.match(r"RFC (\d{4})", cells[0])
            doc = "rfc" + rfc.group(1) if rfc else current[0]
            foreign = {(n, c) for n, c in named_clauses(cells[3] + " " + cells[4])}
            for n, c in foreign:
                check("external survey", n, c)
            own = CLAUSE.findall(cells[0]) + [c for c in CLAUSE.findall(cells[3]) if not any(c == f[1] for f in foreign)]
            for c in own:
                check(f"external survey, {doc}", doc, c)
    for key in docs:
        if key not in listed:
            errors.append(f"external survey: {key} was fetched and is not in the table of documents read")

    # Clauses named in the survey and the blueprint.
    for path in [SURVEY] + sorted((BLUEPRINT / "areas").glob("*.tex")) + [BLUEPRINT / "content.tex"]:
        for name, clause in named_clauses(path.read_text()):
            check(path.name, name, clause)
    return len(docs), cited_rows


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
        if node and not node["lean"] and bool(r["lookup"]) != bool(node["lookup"]):
            errors.append(f"{cid}: the survey {'names' if r['lookup'] else 'does not name'} a clause that would "
                          f"settle it, and the blueprint node {'has' if node['lookup'] else 'has no'} Lookup: paragraph")
        if r["lookup"] and r["grade"] == "Clear":
            errors.append(f"{cid}: graded Clear and still waiting on a clause to be read")
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

    fetched, cited_rows = check_external(status, errors)

    if errors:
        sys.exit("survey check failed:\n  " + "\n  ".join(errors))
    in_model = sum(1 for r in rules if "OID-" in r["model"])
    print(f"survey: {len(rules)} entries ({counts['Clear']} clear, {counts['Vague']} vague, {counts['Silent']} silent), "
          f"{in_model} in the model, {len(rules) - in_model} candidates; {len(rows) - len(rules)} candidate guarantees; "
          f"every citation is a section of the guide")
    print(f"external survey: {cited_rows} cited clauses in {fetched} fetched specifications; every clause cited "
          f"there, in the survey, in the blueprint and in the read assumptions is in the copy that was read")


if __name__ == "__main__":
    main()
