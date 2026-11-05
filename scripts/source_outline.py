#!/usr/bin/env python3
"""Write sources/outline.json: the hash of the guide and its section headings.

  python3 scripts/source_outline.py <guide.docx> <converted.md> "<pandoc version>"

scripts/convert-source.sh runs this after pandoc.  The outline is committed;
the converted text is not.  scripts/check_survey.py checks every section the
survey and the model cite against it.
"""

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADING = re.compile(r"^(#{1,6})\s+(.*)$")
# "4.2.1.2 Remote Presentation ...", "2. Terminology", "6 Annex B ...".
NUMBERED = re.compile(r"^(\d+(?:\.\d+)*)\.?\s+(.*)$")


def main():
    docx, converted, pandoc = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    sections = []
    for line in converted.read_text(encoding="utf-8").splitlines():
        m = HEADING.match(line)
        if not m:
            continue
        text = re.sub(r"[*_\\]", "", m.group(2)).strip()
        n = NUMBERED.match(text)
        if n:
            sections.append({"number": n.group(1), "title": n.group(2).strip(), "level": len(m.group(1))})
    outline = {
        "document": "IATA One ID Technical Implementation Guide",
        "version": "26.3",
        "file": docx.name,
        "sha256": hashlib.sha256(docx.read_bytes()).hexdigest(),
        "converted_with": pandoc,
        "public_copy": "https://standards.atlassian.net/wiki/spaces/OneID/pages/2947416082/Technical+Implementation+Guide",
        "sections": sections,
    }
    (ROOT / "sources" / "outline.json").write_text(json.dumps(outline, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
