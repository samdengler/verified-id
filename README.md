# verified-id

IATA's One ID Technical Implementation Guide, written as code that a computer checks. The guide says how a passenger's wallet holds two digital credentials, a photoid and a boarding pass, and how it presents them to an airline or an airport. This repository surveys every rule in the guide, writes the rules as a Lean model, proves what can be proven about them, and turns what cannot be proven into questions a subject matter expert can answer without reading Lean.

This is a proof of concept. It is not affiliated with or endorsed by IATA, and it is not an implementation of the standard. The repository is private. The guide states no license, so nothing here reproduces its text: rules are described in our own words and cited by section number.

The method and the tooling come from [verified-air](https://github.com/samdengler/verified-air), which does the same for IATA's ONE Order material.

## Where to start

| You want to | Read |
| --- | --- |
| Get the project explained, with one open question worked through | The home page: run `scripts/preview.sh` and open <http://localhost:8000/> |
| See what is proven, what is open, and which questions to decide first | The progress page, at `/progress/` on the same site |
| Read the rules and the open questions without reading code | The review document, at `/review/`: one chapter per requirement, then Open questions |
| See every rule of the guide and how clearly the guide states it | [`docs/one-id-survey.md`](docs/one-id-survey.md) |
| See what the model takes on trust from ISO, OpenID and IATA specifications | The review document's chapter on assumptions, or [`Rules/Core/Assumptions.lean`](Rules/Core/Assumptions.lean) |
| Check the approved guide against the public copy | [`docs/source-crosscheck.md`](docs/source-crosscheck.md) |
| Use the requirements in a spec-driven flow | [`.kiro/specs/README.md`](.kiro/specs/README.md), then one `requirements.md` per module |
| Review or change the model | [`Rules/OneId/`](Rules/OneId/), then [`CLAUDE.md`](CLAUDE.md) and the rest of this README |

## The method

1. **Survey before Lean.** Every rule in the scope of the project is listed in [`docs/one-id-survey.md`](docs/one-id-survey.md) with its requirement word, its section, and a grade: clear when the guide states it, vague when the guide uses an undefined term or states it twice at different strengths, silent when the guide names the situation and gives no rule. Each entry is also a node of the blueprint, so the dependencies between rules are known before any is formalized.
2. **Keep every reading.** Where the guide is vague or silent, the Lean rule takes the undecided part as a parameter, called a reading. A guarantee counts as proven only if it holds under every reading. The model never picks one.
3. **A question is a computed example.** A guarantee that some reading breaks stays open. An example written by hand shows the case under that reading, and Lean computes its result. The example states Given, When and Then in plain words, so an expert can answer the question from the example alone.
4. **Rank the questions, and tell decisions from lookups.** The progress page ranks every open question and every candidate that needs a decision by the number of blueprint cards that depend on it, directly or through other cards. The count comes from the dependency graph. A question that asks what a cited specification says is a lookup: it needs a source to be read, and it is ranked in its own list, since it goes to a reader with the document and the others go to the people who own the standard.
5. **Record where each rule comes from.** Each rule names the sections of the guide it was written from with `@[source]`, and the external specifications it relies on with `@[assumes]`. The build fails on a rule with no source. `@[confirmed]` records a confirmation from outside the model, with a fingerprint that goes out of date when the rule changes. Nothing is confirmed yet.
6. **Critique independently.** After each milestone a reviewer who has not seen the reasoning compares the survey with the guide and every criterion with its theorems.

## What is modelled

Milestone one covers the source conversion, the survey, and the credential data model of §4.1. The counts below are from the build of 2026-11-05; the progress page has the current ones.

| | Count |
| --- | --- |
| Rules of the guide surveyed | 103: 44 clear, 43 vague, 16 silent |
| Requirements in Lean | 9, OID-101 to OID-109 |
| Acceptance criteria | 35: 21 proven, 14 open |
| Open questions in Lean, each with a computed example | 14, from 15 open theorems (two are the same question for the two credentials) |
| Candidates that need a decision before they can be modelled | 41 |
| Candidates that need a source to be read, and no decision | 6, with 3 of the open questions in Lean |
| Theorems proven | 37, of which 21 check a criterion; the others hold under one reading or support another proof |
| Dependencies on external specifications recorded | 28: 10 relied on by the model, 18 for the presentation flows |

The nine requirements:

| ID | Rule | Guide |
| --- | --- | --- |
| OID-101 | What a credential must contain to be accepted as a photoid | §4.1.1 |
| OID-102 | Which recommendations a photoid does not follow | §4.1.1 |
| OID-103 | What a credential must contain to be accepted as a boarding pass | §4.1.2 |
| OID-104 | How long a boarding pass stays valid | §4.1.2 |
| OID-105 | When a credential is expired | §4.1.2, §4.2.1.2 |
| OID-106 | How a data element is named, so it can be requested alone | §4.1 |
| OID-107 | Whether a photoid and a boarding pass are one traveler's | §4.1.2, §3.2 |
| OID-108 | How long a photoid stays valid | not stated in the guide |
| OID-109 | Which kind of document a photoid may be derived from | §2, §4.1.1 |

The presentation flows of §4.2 are surveyed and not yet in Lean. The four candidate guarantees (only requested and consented data is received; a presentation is bound to the device and the request; a photoid and a boarding pass presented together are one traveler's; an expired credential is never accepted) are blueprint nodes G-01 to G-04, each waiting on the rules and decisions it depends on.

## What the guide leaves out

The guide puts the trust model, revocation and normative issuance out of scope (§1.4). They are silent entries C-01 to C-03 in the survey. The model does not fill them in. The survey lists, for each, the guarantees it blocks: a proof of one of those guarantees would need a rule the guide does not give.

## External specifications

The guide builds on ISO/IEC 18013-5, ISO/IEC TS 18013-7, ISO/IEC TS 23220-2 and 23220-4, OpenID4VP, OpenID4VC HAIP, the W3C Digital Credentials API, IATA Resolution 792, ICAO Doc 9303 and several IETF RFCs. None was read for this project. The model takes from each only what the guide says about it:

- Where a rule depends on the content of an external table or format, that content is a parameter of the rule. `PhotoidTables` stands for Tables C.1 to C.3 of ISO/IEC TS 23220-4, and `Resolution792` for what IATA Resolution 792 decides about a boarding pass string. A guarantee is proven only if it holds for every value of the parameter.
- Every dependency is listed once in [`Rules/Core/Assumptions.lean`](Rules/Core/Assumptions.lean) with the clause the guide cites, and a declaration that relies on one names it with `@[assumes "<key>"]`. The attribute rejects an unknown key.
- The examples need some table and some boarding pass format to compute with. [`Rules/OneId/Examples.lean`](Rules/OneId/Examples.lean) uses stand-ins that are invented and labelled as such.

## How the build turns the model into documents

People write the Lean files, the survey, the blueprint statements and the prose chapters. Everything else is computed, so no status, count, ranking or example value is typed by hand.

| Step | What it does | It fails when |
| --- | --- | --- |
| `lake build` | Checks every proof and every `#guard` | A proof is rejected, an example's value changes, or a rule names a source or an assumption that is not listed |
| `lake exe status` | Computes each theorem's and criterion's status, each rule's fingerprint and provenance; writes `build/status.json` and the CSV exports | A theorem depends on `sorry` without `@[open_question]`, a rule has no `@[source]`, an EARS statement or criterion does not follow one EARS template, a rule lacks a story or criteria, or a `@[checks]` tag names a criterion no rule defines |
| `scripts/render_status.py` | Writes the review chapters, the blueprint's `\leanok` markers and the requirement specs | The blueprint names a declaration the build does not report, or `Review/Review.lean` misses a requirement chapter |
| `scripts/check_survey.py` | Checks the survey, the blueprint, the model and the citations against each other | A survey entry has no node and no requirement, a grade disagrees with the blueprint, a count disagrees with the rows, or a citation names a section the guide does not have |
| `lake exe review-doc` | Renders the Verso review document | A chapter names a declaration that does not exist |
| `leanblueprint web`, `checkdecls`, `pdf` | Renders the blueprint and its dependency graph | The blueprint names a Lean declaration that does not exist |
| `scripts/render_progress.py` | Writes the progress page and `build/ranking.json` | A `\uses` names a label that does not exist, or a blueprint section is not in `AREA_ORDER` |
| `scripts/render_home.py` | Writes the home page | The open question the page works through has been proven, or lost its example |

`scripts/build-site.sh` runs all of them and assembles `site/`. It must pass before anything lands on `main`: the pre-push hook in `.githooks/` runs it, and `.github/workflows/ci.yml` runs the same steps.

## The site

| Part | Source | At |
| --- | --- | --- |
| Home page: what the project is, one open question worked through, where each kind of reader should go | `scripts/render_home.py` | `/` |
| Progress page: counts by status, the ranked questions, every rule and candidate as a card | `scripts/render_progress.py` | `/progress/` |
| Review document, in Verso: prose with checked Lean inside it | `Review/` | `/review/` |
| Blueprint, in leanblueprint: numbered statements, a dependency graph, a PDF | `blueprint/src/` | `/blueprint/` |
| Requirement specs, criteria in EARS, in Kiro's layout | `.kiro/specs/` | `/specs/` |
| Exports | `lake exe status` | `/ears.csv`, `/ears-criteria.csv`, `/provenance.csv`, `/assumptions.csv`, `/ranking.json`, `/status.json` |

The site is not published anywhere. The repository is private and has no remote, and GitHub Pages is not available for a private repository on this account's plan. Build it with `scripts/build-site.sh` and serve it with `python3 scripts/serve_site.py`, or do both with `scripts/preview.sh`.

## Building locally

Prerequisites: [elan](https://github.com/leanprover/elan), Python 3.12 or later, graphviz, pandoc, and a TeX installation with `xelatex` and `latexmk` (TinyTeX works).

```sh
lake exe cache get                      # prebuilt Mathlib, once
python3 -m venv .venv && . .venv/bin/activate
pip install leanblueprint==0.0.20       # on macOS with Homebrew graphviz, set
                                        # CFLAGS=-I$(brew --prefix graphviz)/include
                                        # LDFLAGS=-L$(brew --prefix graphviz)/lib
git config core.hooksPath .githooks     # the pre-push gate, once per clone

scripts/convert-source.sh <guide.docx>  # sources/one-id-tig-26.3.md (not committed) and sources/outline.json
python3 scripts/crosscheck_source.py    # compare with the public copy; report in build/
scripts/preview.sh                      # the documents, served at http://localhost:8000
scripts/build-site.sh                   # everything CI builds, assembled in site/
```

The model builds without the converted guide: only the conversion and the cross-check need the document.

## Versions

| Tool | Version |
| --- | --- |
| Lean | `leanprover/lean4:v4.35.0` |
| Mathlib | tag `v4.35.0` |
| Verso | tag `v4.35.0` |
| checkdecls | `master` at `3d42585` |
| leanblueprint | 0.0.20 |
| pandoc | 3.13 |

`lake-manifest.json` pins every Lean dependency to a commit.

## Decisions

Choices made where the request left room, in the order they came up.

1. **The tooling comes from verified-air's `provenance-tags` branch.** The `@[source]` and `@[confirmed]` attributes and the build-time source check are on that branch, one commit ahead of verified-air's `main` and not merged there. It was fetched on 2026-11-05 and ported from: the attributes, the list of sources, the status executable, `render_status.py`, the progress page with its ranking, the Verso review document and the blueprint.
2. **What was left behind.** verified-air's Java and Rust implementation checks, its test oracle, the airline demo, the motion piece, and its Explore, area, tour and home pages are not ported. Open questions list the cards that depend on them on the progress page itself, since there is no Explore page to link to.
3. **Same Lean, Mathlib and Verso versions as verified-air.** The compiled packages were copied from verified-air's checkout, so nothing was downloaded. The model needs little of Mathlib; it stays so that the two projects build alike.
4. **External specifications are parameters and recorded assumptions.** verified-air had no specification it could not read. Here the guide defers to many. `Rules/Core/Assumptions.lean` and the `@[assumes]` attribute are new: they work like the list of sources and `@[source]`, and the status executable exports them. A theorem that relies on an external table is stated for every table.
5. **Sources are sections of the guide.** A source key is `tig-` and a section number. The link is the public Confluence page, whose text is the same as the approved document.
6. **The guide's text is not committed.** `sources/` is ignored except its README and `outline.json`, which holds the hash of the approved document and its section headings. `scripts/check_survey.py` checks every cited section against the outline, so a citation can be checked without the text.
7. **Requirement words decide findings and advisories.** What the guide says with MUST or SHALL is a finding, and a credential with one is rejected. What it says with SHOULD or RECOMMENDED is an advisory, reported and not rejected. A lower-case "must" is not a requirement, as §1.2 of the guide says.
8. **Facts only the issuer knows are inputs of the rules.** The subject of a credential, the departure of the last leg, and the expiry of the passport are known to the issuer and are not data elements the guide defines. The model takes them as inputs of the rules that need them (`Issued`, `Journey`, the document expiry). A relying party sees only the credential.
9. **A credential has an end of validity and no start.** The guide names `validUntil` and nothing else from the validity information.
10. **Survey IDs.** C-01 to C-103 are rules, G-01 to G-04 the candidate guarantees. C-97 to C-100 were added by the critique, and C-101 to C-103 when lookups were separated from decisions. Several requirement words of the guide share one entry when they state one rule. A Lean-backed blueprint node carries the ID of its main survey entry; the survey's Model column names the requirement for the others it covers.
11. **The survey and the blueprint were first written from one list**, then split into the two files, which are maintained by hand from here on as in verified-air. `scripts/check_survey.py` keeps them from drifting.
12. **The ranking counts dependents in the blueprint graph.** A card depends on a question if its `\uses` reaches the question's node. The edges are written by hand, so the ranking is as good as they are. The candidate guarantees have the status waiting and are left out of the ranking; each lists what blocks it.
13. **The pre-push hook is the gate.** With no pull requests, the only place to stop a push to `main` is before it. `.githooks/pre-push` runs `scripts/build-site.sh` and refuses when it fails or when the working tree differs from what is pushed.
14. **The CI workflow has not run.** There is no remote. `.github/workflows/ci.yml` follows verified-air's and runs the same steps as `scripts/build-site.sh`; expect to fix it on its first run.
15. **The EARS section of the PDF is a list.** verified-air's table does not break across pages at this length.
16. **pandoc was added through the dotfiles manifest**, as the machine's convention requires, and committed there.
17. **The gates were tested by breaking them.** Before the first commit, nine deliberate faults were introduced one at a time and each stopped the build: an unknown source key, a rule with no source, an unknown assumption key, a `sorry` without `@[open_question]`, a changed example value, a `@[checks]` tag for a criterion no rule defines, a survey grade that disagrees with the blueprint, a citation of a section the guide does not have, and a blueprint node that names a missing declaration.
18. **Fixes from the independent critique.** A reviewer who had not seen the reasoning read the guide in full on 2026-11-05, ticked every requirement word of the in-scope sections against the survey, and compared every criterion with its theorems. It found 15 problems. All were acted on before the first commit:
    - The model rejected a credential with a repeated name under every reading, on the strength of how ISO/IEC 18013-5 structures an mdoc, which this project has not read. The guide says nothing about it. It is now a reading, and the guarantee is open (OID-106.3).
    - Whether a photoid may be derived from a document other than a passport was graded vague in the survey and then decided in Lean. It is now a reading with its own requirement and open question (OID-109).
    - The departure a boarding pass's validity is measured from was fixed as the scheduled one. It is now a reading, scheduled or actual, and OID-104.1 to 104.3 are proven for whichever the reading names.
    - The photoid check ignored the encoding the guide refers to Table C.1, and treated unlisted data elements differently from the boarding pass check. The tables now carry an encoding, with a proven criterion (OID-101.4), and the reading about unlisted data covers data elements.
    - One theorem tagged as checking a criterion proved less than the criterion. It now proves all of it (OID-106.2).
    - The matching guarantee (OID-107) cannot be given by any check of the two credentials' content, because who a credential is about is fixed at issuance. `no_content_check_identifies_the_traveler` proves that, and the question now asks about issuance as well.
    - Six statements said what an external specification contains beyond the guide's own words. They were reworded or removed, and `Presence` gained a value for anything a table may say besides mandatory and optional.
    - Five survey entries were regraded from clear or silent to vague where the guide states one rule at two strengths or with an undefined mechanism, six entries gained requirement words they had missed, and four entries were added (C-97 to C-100).
    - Three dependency edges that inflated the ranking were moved from definitions to the open theorems the question bears on, and four missing edges from the out-of-scope entries to the guarantees they block were added.
    - Eleven paraphrases that followed the guide's wording too closely were rewritten.

    The reviewer confirmed that every open theorem is false as stated and that each example computes what its text says. The same reviewer then checked the fixes and found one new problem they had introduced: once a repeated name could be allowed, the checks looked only at the first copy of a name, so a second copy in the wrong encoding passed. The checks now look at every copy, and the theorems say so (`photoid_base_encoding`, `boardingPass_strings_follow`). Five smaller points from that pass were also fixed: a theorem about a helper where the criterion was about the whole check (OID-102.4), a sentence that overstated what no content check can do, the meaning of "accepted" when the source document is checked by its own rule, one leftover paraphrase, and a missing example for the boarding pass half of OID-106.3.
19. **A home page for a reader with no context, and no Blueprint link in the bar** (added at Sam's request). The site first opened on the progress page, which drops a reader into tiles and rankings. The root is now a home page ported from verified-air's: what One ID and the project are in plain words, one open guarantee worked through from the model (the rule, the guarantee, the example's Given and When, what Lean computes, and the open point), four links by kind of reader, what is in Lean, surveyed and left out by the guide, the status tiles, the top three of "Decide these first", and what the model takes on trust. The worked guarantee is `QUESTION` in `scripts/render_home.py`; the build stops when it is proven. The progress page moved to `/progress/`. The bar now has Progress and Review document only, as in verified-air: the blueprint is for people who work on the Lean, and is linked from the home page and the review document.
20. **Needs a source, apart from needs a decision** (added at Sam's request). Some questions ask what a specification the guide cites says: whether Table C.1 marks the portrait mandatory, whether the clause two profiles cite for issuer data authentication includes the validity check. No one has to decide those; someone has to read the clause. A blueprint node names the clause in a paragraph that starts with `Lookup:`. A candidate with one has the status needs a source, an open question with one carries the same label beside its own, and the progress page ranks both under "Look these up first", apart from "Decide these first". The survey has the clause in its column "Answered by reading", and `scripts/check_survey.py` keeps the two in step. Three questions that mixed a lookup with a decision were split, which added C-101 to C-103. Only a question that reading alone would settle is marked: one where the guide contradicts itself stays a decision whatever the cited clause says. If a clause, once read, does not settle its question, the paragraph is removed and the question becomes a decision.
