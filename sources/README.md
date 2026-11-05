# Sources

The model is written from one document: IATA's One ID Technical Implementation Guide, version 26.3, in its approved form.

The guide states no license. So this repository does not contain its text. It cites the guide by section number, describes each rule in its own words, and quotes at most a few words. This folder is ignored by git except for this file and `outline.json`.

## Files

| File | Committed | What it is |
| --- | --- | --- |
| `README.md` | yes | This file. |
| `outline.json` | yes | The SHA-256 of the approved document, the pandoc version used, and the number and heading of each of its 28 sections. `scripts/check_survey.py` checks every section the survey, the blueprint and the model cite against it. |
| `one-id-tig-26.3.md` | no | The guide converted to markdown. Produce it with the command below. |

## Producing the converted text

```sh
scripts/convert-source.sh /path/to/One+ID+Technical+Implementation+Guide-26.3.docx
```

The script runs `pandoc --from=docx --to=gfm --wrap=none` and rewrites `outline.json`. If the hash in `outline.json` changes, the document is not the one the model was written from: survey it again before trusting a citation.

## The public copy

IATA publishes the guide at <https://standards.atlassian.net/wiki/spaces/OneID/pages/2947416082/Technical+Implementation+Guide>. `docs/source-crosscheck.md` records how it compares with the approved document: the body text is the same.

## Specifications the guide refers to

The guide builds on ISO/IEC 18013-5, ISO/IEC TS 18013-7, ISO/IEC TS 23220-2 and 23220-4, OpenID4VP, OpenID4VC HAIP, the W3C Digital Credentials API, IATA Resolution 792, and others. None of them is in this folder, and the model was written without reading them. `Rules/Core/Assumptions.lean` lists each dependency with the clause the guide cites, and the review document shows the list.
