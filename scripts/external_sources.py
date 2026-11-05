#!/usr/bin/env python3
"""The public specifications the guide refers to: where each is fetched from,
and the record of what was fetched.

  python3 -I scripts/external_sources.py list
      one line per document: name, file, kind, address (tab separated)
  python3 -I scripts/external_sources.py record <sources/external> <today>
      read the fetched files and their converted text, and write
      sources/external.json

scripts/fetch-sources.sh runs both.  The fetched files and their text stay out
of the repository (sources/ is ignored).  sources/external.json is committed:
for each document its address, the day it was fetched, its SHA-256, the
version and the copyright line as the document prints them, and the number and
title of each of its sections.  scripts/check_survey.py checks every clause
that docs/external-survey.md and the read assumptions cite against it.

The version and copyright strings below were typed from the documents.  The
record step fails if a fetched document does not contain them, so a document
that changed at its address is noticed.

The ISO/IEC documents and IATA Resolution 792 are sold, and the One ID
business requirements are not public.  They are not fetched and not read.
"""

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# name: the directory under sources/external and the key the external survey
#   uses.
# assumptions: the entries of Rules/Core/Assumptions.lean this document covers.
# cited: the address in the guide's reference list, where it differs from the
#   address fetched.
# guide: the version the guide names.
# version, licence: strings the document prints.
DOCS = [
    dict(name="openid4vp", title="OpenID for Verifiable Presentations 1.0",
         assumptions=["x-openid4vp"],
         url="https://openid.net/specs/openid-4-verifiable-presentations-1_0.html",
         file="openid-4-verifiable-presentations-1_0.html", kind="html",
         guide="version 1.0 published 9 July 2025",
         version=["OpenID for Verifiable Presentations 1.0", "9 July 2025", "Final"],
         licence="Copyright (c) 2025 The OpenID Foundation",
         note="This address holds the latest revision with errata. The text as approved is at the same "
              "address ending in -final.html."),
    dict(name="haip", title="OpenID4VC High Assurance Interoperability Profile 1.0",
         assumptions=["x-haip"],
         url="https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0.html",
         file="openid4vc-high-assurance-interoperability-profile-1_0.html", kind="html",
         guide="version 1.0 published 24 December 2025",
         version=["OpenID4VC High Assurance Interoperability Profile 1.0", "24 December 2025", "Final"],
         licence="Copyright (c) 2025 The OpenID Foundation",
         note="This address holds the latest revision with errata."),
    dict(name="openid4vci", title="OpenID for Verifiable Credential Issuance 1.0",
         assumptions=[],
         url="https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html",
         file="openid-4-verifiable-credential-issuance-1_0.html", kind="html",
         guide="version 1.0 published 16 September 2025",
         version=["OpenID for Verifiable Credential Issuance 1.0", "16 September 2025", "Final"],
         licence="Copyright (c) 2025 The OpenID Foundation",
         note="The guide cites it for terms (§2) and in the informative Annex A only, so no assumption names it."),
    dict(name="w3c-dc-api", title="W3C Digital Credentials",
         assumptions=["x-w3c-dc-api"],
         url="https://www.w3.org/TR/2026/WD-digital-credentials-20260716/",
         file="WD-digital-credentials-20260716.html", kind="html",
         guide="draft of 16 July 2026",
         version=["W3C Working Draft", "16 July 2026"],
         licence="permissive document license",
         note="A dated working draft. The document says it may be replaced at any time."),
    dict(name="icao-9303-10", title="ICAO Doc 9303 Part 10",
         assumptions=["x-icao-9303-10"],
         url="https://www.icao.int/sites/default/files/publications/DocSeries/9303_p10_cons_en.pdf",
         file="9303_p10_cons_en.pdf", kind="pdf",
         guide="no version named, and no address given",
         version=["Eighth Edition, 2021", "Part 10: Logical Data Structure"],
         licence="© ICAO 2021",
         note="The guide's reference list gives an address for Part 11 only. This is the same address with "
              "p10 in place of p11. The file is the consolidated text with Amendment No. 1."),
    dict(name="icao-9303-11", title="ICAO Doc 9303 Part 11",
         assumptions=["x-icao-9303-11"],
         url="https://www.icao.int/sites/default/files/publications/DocSeries/9303_p11_cons_en.pdf",
         file="9303_p11_cons_en.pdf", kind="pdf",
         guide="no version named",
         version=["Eighth Edition, 2021", "Part 11: Security Mechanisms for MRTDs"],
         licence="© ICAO 2021",
         note="The file is the consolidated text with Amendment No. 1."),
    dict(name="iata-bcbp-guide", title="IATA Bar Coded Boarding Pass Implementation Guide",
         assumptions=["x-iata-bcbp-guide"],
         url="https://www.iata.org/contentassets/1dccc9ed041b4f3bbdcf8ee8682e75c4/"
             "2021_03_02-bcbp-implementation-guide-version-7-.pdf",
         file="bcbp-implementation-guide-version-7.pdf", kind="pdf",
         guide="the open implementation guide, listed under Resolution 792",
         version=["IMPLEMENTATION GUIDE", "Effective Date: 1st June, 2018", "Seven Edition"],
         licence="© IATA 2017",
         note="A guide to Resolution 792. It is not the resolution, which is sold and was not read."),
    dict(name="rfc8949", title="IETF RFC 8949 (CBOR)",
         assumptions=["x-cbor-tstr"],
         url="https://www.rfc-editor.org/rfc/rfc8949.txt",
         cited="https://datatracker.ietf.org/doc/html/rfc8949",
         file="rfc8949.txt", kind="rfc",
         guide="no version named",
         version=["Request for Comments: 8949", "December 2020"],
         licence="Copyright (c) 2020 IETF Trust"),
    dict(name="rfc9052", title="IETF RFC 9052 (COSE)",
         assumptions=["x-cose"],
         url="https://www.rfc-editor.org/rfc/rfc9052.txt",
         cited="https://datatracker.ietf.org/doc/html/rfc9052",
         file="rfc9052.txt", kind="rfc",
         guide="no version named",
         version=["Request for Comments: 9052", "August 2022"],
         licence="Copyright (c) 2022 IETF Trust"),
    dict(name="rfc9180", title="IETF RFC 9180 (HPKE)",
         assumptions=["x-hpke"],
         url="https://www.rfc-editor.org/rfc/rfc9180.txt",
         cited="https://datatracker.ietf.org/doc/rfc9180/",
         file="rfc9180.txt", kind="rfc",
         guide="no version named",
         version=["Request for Comments: 9180", "February 2022"],
         licence="Copyright (c) 2022 IETF Trust"),
    dict(name="rfc5280", title="IETF RFC 5280",
         assumptions=["x-rfc5280"],
         url="https://www.rfc-editor.org/rfc/rfc5280.txt",
         cited="https://datatracker.ietf.org/doc/html/rfc5280",
         file="rfc5280.txt", kind="rfc",
         guide="no version named",
         version=["Request for Comments: 5280", "May 2008"],
         licence="Copyright (C) The IETF Trust (2008)"),
]

LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
MD_HEADING = re.compile(r"^(#{1,6})\s+(.*)$")
NUMBERED = re.compile(r"^(?:Appendix\s+)?((?:[A-Z]|\d+)(?:\.\d+)*)\.?\s+(\S.*)$")
RFC_HEADING = re.compile(r"^(?:Appendix\s+)?((?:[A-Z]|\d+)(?:\.\d+)*)\.\s+(\S.*)$")
PDF_CONTENTS = re.compile(r"^\s*(?:APPENDIX\s+)?((?:[A-Z]|\d+)(?:\.\d+)*)\.?\s+(\S.*?)\s*\.{4,}.*$")
PDF_BODY = re.compile(r"^\s{0,12}(\d+\.\d+(?:\.\d+)+)\.?\s+([A-Z].*?)\s*$")


def clean(title):
    title = re.sub(r"[`*\\]", "", title)
    return re.sub(r"\s+", " ", title).strip()


def outline_md(text):
    out = []
    for line in text.splitlines():
        m = MD_HEADING.match(line)
        if not m:
            continue
        n = NUMBERED.match(clean(LINK.sub(r"\1", m.group(2))))
        if n:
            out.append((n.group(1), n.group(2)))
    return out


def outline_rfc(text):
    out = []
    for line in text.splitlines():
        m = RFC_HEADING.match(line)
        if m and not line.rstrip().endswith(".") and len(line) < 90:
            out.append((m.group(1), clean(m.group(2))))
    return out


def outline_pdf(text):
    out = []
    for line in text.splitlines():
        m = PDF_CONTENTS.match(line) or PDF_BODY.match(line)
        if m and len(m.group(2)) < 110 and not m.group(2).rstrip().endswith("."):
            out.append((m.group(1), clean(m.group(2))))
    return out


OUTLINE = {"html": outline_md, "rfc": outline_rfc, "pdf": outline_pdf}
TEXT = {"html": "text.md", "rfc": None, "pdf": "text.txt"}


def record(base, today):
    path = ROOT / "sources" / "external.json"
    old = {}
    if path.exists():
        old = {d["name"]: d for d in json.loads(path.read_text())["documents"]}
    docs, changed = [], []
    for d in DOCS:
        folder = base / d["name"]
        raw = folder / d["file"]
        if not raw.exists():
            sys.exit(f"not fetched: {raw}")
        text_file = folder / TEXT[d["kind"]] if TEXT[d["kind"]] else raw
        text = text_file.read_text(encoding="utf-8", errors="replace")
        flat = re.sub(r"\s+", " ", text)
        for s in d["version"] + [d["licence"]]:
            if s not in flat:
                sys.exit(f"{d['name']}: the fetched document does not contain {s!r}. "
                         "It is not the document this project read.")
        seen, sections = set(), []
        for number, title in OUTLINE[d["kind"]](text):
            if number not in seen:
                seen.add(number)
                sections.append({"number": number, "title": title})
        if not sections:
            sys.exit(f"{d['name']}: no section headings found")
        sha = hashlib.sha256(raw.read_bytes()).hexdigest()
        before = old.get(d["name"])
        if before and before["sha256"] != sha:
            changed.append(d["name"])
        entry = {
            "name": d["name"],
            "title": d["title"],
            "assumptions": d["assumptions"],
            "address": d["url"],
            "retrieved": before["retrieved"] if before and before["sha256"] == sha else today,
            "sha256": sha,
            "bytes": raw.stat().st_size,
            "guide_names": d["guide"],
            "version_printed": d["version"],
            "copyright_printed": d["licence"],
            "sections": sections,
        }
        if d.get("cited"):
            entry["address_in_guide"] = d["cited"]
        if d.get("note"):
            entry["note"] = d["note"]
        docs.append(entry)
    out = {
        "what": "The public specifications the One ID guide refers to, as fetched by scripts/fetch-sources.sh. "
                "The documents themselves are not in the repository.",
        "documents": docs,
    }
    path.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n")
    for d in docs:
        print(f"{d['name']:16} {d['sha256'][:12]}  {len(d['sections']):4} sections  fetched {d['retrieved']}")
    if changed:
        print("CHANGED since the last record: " + ", ".join(changed)
              + ". Read the differences before trusting docs/external-survey.md.")


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        for d in DOCS:
            print("\t".join([d["name"], d["file"], d["kind"], d["url"]]))
    elif len(sys.argv) == 4 and sys.argv[1] == "record":
        record(Path(sys.argv[2]), sys.argv[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
