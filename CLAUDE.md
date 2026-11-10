# CLAUDE.md

IATA's One ID Technical Implementation Guide as a Lean model, with a survey of its rules, review documents and requirement specs generated from the model. The method and tooling come from `verified-air` (its `provenance-tags` branch). The README explains the design and records every decision; read it before changing structure.

## The source and what may be copied from it

- The source is the approved guide, version 26.3. It states no license. Cite it by section number, describe rules in our own words, and keep any quotation to a few words.
- Never commit the converted text, or the text of a specification the guide refers to. `sources/` is ignored except `README.md`, `outline.json` and `external.json`. `scripts/convert-source.sh` produces the guide's text and outline, and `scripts/fetch-sources.sh` fetches the public specifications and writes `external.json`.
- The repository is public, and CI publishes the site to https://samdengler.github.io/verified-id/ (README, decision 35). Everything committed and everything `scripts/assemble-site.sh` puts in `site/` is public, so the rules here about the guide's text and the specifications' text apply to both.
- Never state what a specification the guide refers to says from general knowledge, in Lean, in a docstring, in the survey or on the site. A dependency is a parameter of the rule (such as `PhotoidTables` or `Resolution792`) or an entry in `Rules/Core/Assumptions.lean`, named on the declaration with `@[assumes "<key>"]`. Each entry says whether the specification was read.
- The public specifications were fetched and read: OpenID4VP, the OpenID4VC high assurance profile, the W3C Digital Credentials draft, ICAO Doc 9303 parts 10 and 11, IATA's BCBP implementation guide, and RFCs 8949, 9052, 9180 and 5280. A statement about one of them comes from the fetched text and names the document and the clause, such as "OpenID4VP §6.4". `docs/external-survey.md` records each clause the guide cites, and only those clauses and what they depend on were read: do not state what another clause says without reading it first and adding it there. Several of these documents forbid copying, so describe a clause in our own words and quote at most a few words.
- The ISO/IEC documents (18013-5, TS 18013-7, TS 23220-2, TS 23220-4) and IATA Resolution 792 are sold, and the One ID business requirements are not public. They were not read. Model only what the guide itself says about them, and do not look for unofficial copies. If Sam provides one, add it to `scripts/external_sources.py`, survey its cited clauses, and change the assumption's `read` field.
- No cryptography is modelled. Keys, nonces and origins are values that can only be compared, the outcome of a signature check is a field, and what an unread ISO clause defines (such as a session transcript, `IsoTranscripts`) is a parameter. Say so wherever a guarantee about presentation is shown, and never claim that a signature or a protocol is verified.
- The guide puts the trust model, revocation and issuance out of scope. They are silent entries in the survey (C-01 to C-03), each with the guarantees it blocks. Do not fill them in.

## Survey first, then Lean

- Every rule of the guide is in `docs/one-id-survey.md` before any Lean is written for it, graded clear, vague or silent, with its requirement word and section. Each entry is a blueprint node, or names the requirement that models it.
- Where the guide is vague or silent, the rule takes the undecided part as a parameter (a reading, such as `PhotoidReading` or `MatchReading`). A guarantee is proven only if it holds under every reading and for every content of the external parameters; otherwise it is open, tagged `@[open_question]`, with a `@[case]` example that shows the case under the reading that breaks it. A proven version for one reading may follow, named `<open theorem's name>_of_<reading>` and tagged with no criterion; the progress page pairs the two by that name. `_of_` is reserved for a reading: a version that holds in one profile is named `_in_<profile>`, and one that needs a further hypothesis `_if_<hypothesis>`; the progress page does not show either as a decision. Never pick a reading for the business and then prove the guarantee.
- An open question is written so a subject matter expert can answer it without reading Lean: the example's docstring states Given, When and Then, its result is a record whose fields label each part, and the theorem's docstring ends with the question.
- Tag a theorem `@[checks "ID"]` only if it proves that criterion for every input. A criterion written for one reading is the same as an `_of_` theorem: write that instead, with no criterion.
- Every rule with an EARS ID names its sources with `@[source "<key> ..."]`, keys listed once in `Rules/Core/Sources.lean`. The attribute rejects an unknown key, and `lake exe status` fails on a rule with none. A rule written where the guide states nothing also names a modeller source.
- `@[confirmed <method> "<date>" "<who>" "<what was confirmed>" "<fingerprint>"]` records that a subject matter expert, production data or a second independent source confirmed a rule as written. Write one only for a confirmation that happened, and name a team or a role unless a person agrees to be named. Nothing is confirmed yet. The fingerprint comes from the rule's entry in `build/status.json`; a rule edited after its confirmation shows as confirmed but out of date.

## What the site may claim

- Statuses, counts, rankings and example values are computed by the build. Never type one by hand: change the Lean or the blueprint and rebuild.
- Proven means Lean checked a proof that holds for every input, every reading and every content of the external parameters. Open means the theorem has no proof and is tagged `@[open_question]`.
- Nothing in the build searches for counterexamples. Examples are written by hand and Lean computes their results, so say "an example shows the case", never "Lean found".
- The stand-in tables and the stand-in boarding pass format in `Rules/OneId/Examples.lean`, and the stand-in session transcripts in `Rules/OneId/PresentationExamples.lean`, are invented. Say so wherever they are shown.
- This is a proof of concept, not affiliated with IATA.

## Authored and generated files

| Authored | Generated |
| --- | --- |
| `Rules/**/*.lean`: rule docstrings carry `EARS:`, `Story:` and `* OID-10n.m:` criteria; each rule names its sources and its external assumptions; examples state Given, When and Then and return records whose fields label each part | `Review/Review/Generated/` (`scripts/render_status.py`): a chapter per requirement, the open questions, the assumptions, the front page cards, the EARS table |
| `docs/one-id-survey.md`, the survey | `.kiro/specs/` (committed), `blueprint/src/*.generated.tex` |
| `blueprint/src/content.tex` and `blueprint/src/areas/*.tex`, without `\leanok`; nodes use `Counterexample:`, `Case to check:`, `Open point:`, `Lookup:`, `Blocks:`, `External:` and `Source:` paragraphs, which the progress page reads; a candidate carries its survey ID at the end of its title | `build/home/index.html` (`scripts/render_home.py`), the site root; `build/progress/index.html`, at `/progress/`, and `build/ranking.json` (`scripts/render_progress.py`, reading the graph through `scripts/graph_model.py`) |
| `Review/Review/{Overview,Objects}.lean`, `Review/Review.lean`, `Review/Review/Status.lean`, `Review/review.css`, `Review/review.js` | `build/status.json`, `ears.csv`, `ears-criteria.csv`, `provenance.csv`, `assumptions.csv` (`lake exe status`) |
| `docs/source-crosscheck.md`, `sources/README.md`, `scripts/` | `sources/outline.json` (committed) and `sources/one-id-tig-26.3.md` (ignored), both by `scripts/convert-source.sh` |
| `Oracle/` (the oracle's JSON; `Oracle.rules` and `Oracle.presentationRules`, the reading points each rule reads, per profile for a presentation); `Exports/` (the credential and presentation scenarios, the settings and open theorems of each reading point, the identifier list) | `build/one-id-data/scenarios.json`, `readings.json`, `decisions.jsonl`, the same three in `build/one-id-data/presentation/`, and `build/one-id-identifiers.json` (`lake exe oneid-facts`); `build/one-id-data/model.json` (`scripts/export_one_id.py`) |
| `docs/external-survey.md`, the survey of the clauses the guide cites in the public specifications; the list of documents in `scripts/external_sources.py` | `sources/external.json` (committed) and `sources/external/` (ignored), both by `scripts/fetch-sources.sh` |

- A question is a lookup when reading a clause the guide cites would settle it, with nothing left for anyone to decide. Its blueprint node names the clause in a `Lookup:` paragraph and its survey row in the column "Answered by reading". A candidate with one shows as needs a source; an open theorem's node with one keeps open question and gains the same label. Do not mark a question where the guide contradicts itself, or one that mixes a lookup with a decision: split it into two entries. When the clause has been read, remove the paragraph: the question is then answered, or it is a decision.
- The survey and the blueprint are both written by hand. `scripts/check_survey.py` keeps them together: it fails on a survey entry with no node and no requirement, a node with no entry, a grade that disagrees with `\notready`, a lookup in one and not the other, a count that disagrees with the rows, or a citation of a section the guide does not have.
- The same script checks clauses of the specifications that were read against `sources/external.json`: in the external survey, in the statements of read assumptions, and wherever the survey or the blueprint names a document and then a clause ("OpenID4VP §5.2", "HAIP §5", "BCBP guide §2.2.1", "RFC 5280 §3.1"). Write a clause in one of those forms so the check sees it. It also fails when an assumption's `read` field and the fetched documents disagree.
- A new requirement needs `{include 1 Review.Generated.<ID without the dash>}` (such as `OID201`) and its import in `Review/Review.lean`; `render_status.py` fails until it is there.
- A new blueprint section must be added to `AREA_ORDER` in `scripts/graph_model.py`; the build stops until it is.
- The bar at the top of every page is defined in `scripts/site_nav.py`: the site name, which leads to the home page, then Progress and Review document. `Review/review.js` repeats its links for the review document, so change both together. The blueprint is not in the bar; the home page and the review document link it.
- The home page works through one open guarantee, `QUESTION` in `scripts/render_home.py`. If it is proven, the build stops until another open question with an example is picked there. A new part of the site needs a card on the home page.

## Working on the site

- Work locally. `scripts/preview.sh` rebuilds the documents and serves the site at http://localhost:8000.
- For a visual change, take screenshots (headless Chrome works) and show them before committing.
- Where a page names something a reader may not know, link it in the sentence: the guide and an external specification through the model's own lists (`Rules/Core/Sources.lean`, and the `url` of each entry in `Rules/Core/Assumptions.lean`, which come from the guide's reference list), a credential or a concept to its chapter in the review document by its Verso tag. Check that an outside address answers before adding it.
- `scripts/build-site.sh` must pass before anything lands on `main`. It runs everything CI runs. Commit `.kiro/specs` whenever `scripts/render_status.py` changes it; CI and the pre-push hook fail if the committed specs are stale.
- Turn the hook on once per clone with `git config core.hooksPath .githooks`. It runs `scripts/build-site.sh` before a push to `main`.
- Commit straight to `main`. No pull requests, no merge commits. A push to `main` whose build passes publishes the site; set the repository variable `PAGES_ENABLED` to `false` to stop publishing.

## The data a product site reads

- `build/one-id-data/` is what a product site such as Verified Airline reads; the README describes each file. Its Lean stays in `Oracle/` and `Exports/`, in namespaces outside `Rules`, so the status counts and the specs do not include it.
- The default scenario (`"default": true`) gives every check the same result under every reading setting, and so does the default presentation of each profile in `presentation/`. Never make one depend on a reading: give it inputs that avoid every undecided point. `lake exe oneid-facts` stops otherwise.
- The top-level files of `build/one-id-data/` are what Verified Airline's check reads: a new reading point or rule there breaks it. Presentation data goes in `presentation/`.
- A scenario that reproduces a `@[case]` example names it, and `Exports.exampleChecks` recomputes the example's record from the scenario's inputs. Add a check there with a new one; the build stops on a scenario that disagrees.
- Labels and questions come from docstrings, never typed in `Exports/`. A new reading point needs its encoder and decoder in `Oracle/Handle.lean`, its place in `Oracle.rules`, and an entry in `Exports.points` with its open theorems; the build checks each against the definitions.

## Areas and requirement IDs

`Rules/Core/` holds what every area shares: attributes, sources, assumptions and time. Each area of the guide has its own range of requirement IDs.

| Area | Guide | IDs | Blueprint file |
| --- | --- | --- | --- |
| Credential data model | §4.1 | OID-101 to OID-199 | `areas/credentials.tex` |
| Remote presentation, and the core all three profiles share | §4.2, §4.2.1 | OID-201 to OID-299 | `areas/remote.tex` |
| Proximity presentation | §4.2.2 | OID-301 to OID-399 | `areas/proximity.tex` |
| Functional requirements and assumptions | §3 | OID-401 to OID-499 | `areas/requirements.tex` |

Requirement IDs and survey IDs (C-01, G-01) never renumber. A concept used by more than one area is defined once, in the area that owns it, and the others import it.

## Milestones

- Work proceeds in milestones: a survey round, then an area's rules in Lean. Each milestone ends with `scripts/build-site.sh` passing, a commit, and an annotated tag `milestone/<name>`.
- Milestone one, `credential-data-model`: the source conversion, the survey and the credential data model.
- Milestone two, `presentation-flows`: the shared core of §4.2 (OID-201, OID-202, OID-207), the OpenID4VP profile (OID-203 to OID-205), the mdoc profile's request (OID-206) and the keys of a proximity session (OID-301), with G-01 to G-04 stated as theorems. Its tag is on the commit that handled the critique's 17 findings.
- Next: the ISO documents, if they are obtained, which settle the lookups and the session transcripts; the requirements of §3 that are still candidates.
- An independent critique pass follows each milestone's Lean: a reviewer who has not seen the reasoning compares every criterion with its theorems and the survey with the guide. Its findings and what was done about each go in the README's decisions.

## Versions

Lean, Mathlib and Verso are on `v4.35.0`, the versions `verified-air` uses. leanblueprint is 0.0.20.

## Writing

Prose on the site, in docstrings, in the survey and in the README follows one style: no em or en dashes; short declarative sentences; headings that name the topic; no "X, not Y" contrasts, rhetorical setups or filler adverbs. Business-facing text uses the status words already on the site: modelled, proven, open question, needs a decision, needs a source, ready to build, waiting; and for criteria, proven, example only, open, not checked.
