# Sources

The model is written from IATA's One ID Technical Implementation Guide, version 26.3, in its approved form, and from the public specifications that guide refers to.

The guide states no license. So this repository does not contain its text. It cites the guide by section number, describes each rule in its own words, and quotes at most a few words. The same holds for the specifications: several forbid copying, and none of their text is here. This folder is ignored by git except for this file, `outline.json` and `external.json`.

## Files

| File | Committed | What it is |
| --- | --- | --- |
| `README.md` | yes | This file. |
| `outline.json` | yes | The SHA-256 of the approved document, the pandoc version used, and the number and heading of each of its 28 sections. `scripts/check_survey.py` checks every section the survey, the blueprint and the model cite against it. |
| `one-id-tig-26.3.md` | no | The guide converted to markdown. Produce it with the command below. |
| `external.json` | yes | For each public specification that was read: its address, the day it was fetched, its SHA-256, the version and the copyright line the copy prints, and the number and title of each of its sections. `scripts/check_survey.py` checks every clause cited from one of them against it. |
| `external/` | no | One folder for each fetched specification, with the file as fetched and its text. Produce it with `scripts/fetch-sources.sh`. |

## Producing the converted text

```sh
scripts/convert-source.sh /path/to/One+ID+Technical+Implementation+Guide-26.3.docx
```

The script runs `pandoc --from=docx --to=gfm --wrap=none` and rewrites `outline.json`. If the hash in `outline.json` changes, the document is not the one the model was written from: survey it again before trusting a citation.

## The public copy

IATA publishes the guide at <https://standards.atlassian.net/wiki/spaces/OneID/pages/2947416082/Technical+Implementation+Guide>. `docs/source-crosscheck.md` records how it compares with the approved document: the body text is the same.

## Specifications the guide refers to

```sh
scripts/fetch-sources.sh
```

The script fetches the public specifications: OpenID4VP 1.0, the OpenID4VC high assurance profile 1.0, OpenID4VCI 1.0, the W3C Digital Credentials draft of 16 July 2026, ICAO Doc 9303 parts 10 and 11, IATA's Bar Coded Boarding Pass implementation guide, and RFCs 8949, 9052, 9180 and 5280. It converts HTML with pandoc and PDF with `pdftotext`, and rewrites `external.json`. The list of documents, with the version and copyright line each must print, is in `scripts/external_sources.py`. The script stops if a fetched copy does not print them, and reports any copy whose hash changed since the last run.

`docs/external-survey.md` records what the clauses the guide cites say. Only those clauses, and what they depend on, were read.

Treat the fetched files as untrusted. Keep scripts out of `external/`, and run Python that reads them in isolated mode (`-I`), as the fetch script does.

Not fetched and not read: ISO/IEC 18013-5, ISO/IEC TS 18013-7, ISO/IEC TS 23220-2 and ISO/IEC TS 23220-4, which ISO sells; IATA Resolution 792, which IATA sells; and the One ID business requirements, which are not public. `Rules/Core/Assumptions.lean` lists every dependency with the clause the guide cites and says for each whether its specification was read. The review document shows the list.
