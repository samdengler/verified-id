#!/usr/bin/env python3
"""Compare the approved guide with its public Confluence copy.

  python3 scripts/crosscheck_source.py [path to the .docx]

Fetches the public page through Confluence's read-only page API, renders both
copies to plain text with pandoc, and compares them word by word, ignoring
layout.  It also compares the headings and the link targets.  The report goes
to build/source-crosscheck.md; docs/source-crosscheck.md records the result of
the last run by hand, with its date.

This is not part of scripts/build-site.sh: it needs the .docx and the network.
Run it when either copy changes.  Needs pandoc.
"""

import difflib
import json
import re
import subprocess
import sys
import tempfile
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE_ID = "2947416082"
API = f"https://standards.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.view,version,history"
DEFAULT_DOCX = Path.home() / "Downloads/Delta/OneID/One+ID+Technical+Implementation+Guide-26.3.docx"
QUOTES = {"“": '"', "”": '"', "‘": "'", "’": "'", "–": "-", "—": "-",
          " ": " ", "​": ""}


def pandoc(args, text=None):
    return subprocess.run(["pandoc", *args], input=text, capture_output=True, text=True, check=True).stdout


def words(text):
    """The words of a plain-text rendering, without table rules and typographic variants."""
    text = unicodedata.normalize("NFKC", text)
    for a, b in QUOTES.items():
        text = text.replace(a, b)
    text = re.sub(r"-{3,}", " ", text)
    return re.sub(r"[|+]", " ", text).split()


def headings(markdown):
    out = []
    for line in markdown.splitlines():
        if re.match(r"#{1,6} ", line):
            line = re.sub(r"<[^>]+>", "", line)
            out.append(re.sub(r"\s+", " ", re.sub(r"[*_\\]", "", line)).strip())
    return out


def links(markdown):
    found = re.findall(r'https?://[^\s<>)\]"]+', markdown)
    return sorted({u.rstrip(").,>\\") for u in found} - {"https://"})


def main():
    docx = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DOCX
    request = urllib.request.Request(API, headers={"User-Agent": "verified-id-crosscheck"})
    with urllib.request.urlopen(request, timeout=60) as response:
        page = json.load(response)
    with tempfile.TemporaryDirectory() as tmp:
        html = Path(tmp) / "confluence.html"
        html.write_text(page["body"]["view"]["value"], encoding="utf-8")
        public_text = pandoc(["-f", "html", "-t", "plain", "--wrap=none", str(html)])
        public_md = pandoc(["-f", "html", "-t", "gfm", "--wrap=none", str(html)])
    approved_text = pandoc(["-f", "docx", "-t", "plain", "--wrap=none", str(docx)])
    approved_md = pandoc(["-f", "docx", "-t", "gfm", "--wrap=none", str(docx)])

    a, b = words(approved_text), words(public_text)
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
    spans = [op for op in matcher.get_opcodes() if op[0] != "equal"]
    report = [
        "# Cross-check of the approved guide against its public copy",
        "",
        f"Approved copy: `{docx.name}`, {len(a)} words.",
        f"Public copy: Confluence page {PAGE_ID}, version {page['version']['number']} of "
        f"{page['version']['when'][:10]}, {len(b)} words.",
        "",
        f"## Text: {len(spans)} differing span(s)",
        "",
    ]
    for tag, i1, i2, j1, j2 in spans:
        before = " ".join(a[max(0, i1 - 6):i1])
        report.append(f"- {tag}, after \"...{before}\": {i2 - i1} word(s) only in the approved copy, "
                      f"{j2 - j1} only in the public copy.")
        # The first words only: enough to find the place, short enough to quote.
        if i2 > i1:
            report.append(f"  - approved copy starts: \"{' '.join(a[i1:i1 + 12])}\"")
        if j2 > j1:
            report.append(f"  - public copy starts: \"{' '.join(b[j1:j1 + 12])}\"")
    ha, hb = headings(approved_md), headings(public_md)
    report += ["", "## Headings", ""]
    diff = [l for l in difflib.unified_diff(ha, hb, "approved", "public", lineterm="", n=0)
            if not l.startswith(("---", "+++", "@@"))]
    report += [f"- `{l}`" for l in diff] or ["- The same headings, in the same order."]
    la, lb = links(approved_md), links(public_md)
    report += ["", "## Link targets", ""]
    only = [f"- only in the approved copy: {u}" for u in la if u not in lb] + \
           [f"- only in the public copy: {u}" for u in lb if u not in la]
    report += only or ["- The same link targets."]
    out = ROOT / "build" / "source-crosscheck.md"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(report) + "\n")
    print(f"{len(spans)} differing span(s) in the text, {len(diff)} heading difference(s), "
          f"{len(only)} link difference(s); report in {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
