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
| See what the model takes from ISO, OpenID and IATA specifications, and which of them were read | The review document's chapter on assumptions, or [`Rules/Core/Assumptions.lean`](Rules/Core/Assumptions.lean) |
| See what the public specifications say in the clauses the guide cites, and where they differ from the guide | [`docs/external-survey.md`](docs/external-survey.md) |
| Check the approved guide against the public copy | [`docs/source-crosscheck.md`](docs/source-crosscheck.md) |
| Use the requirements in a spec-driven flow | [`.kiro/specs/README.md`](.kiro/specs/README.md), then one `requirements.md` per module |
| Build a site on the model, or check an implementation against it | [The data a product site reads](#the-data-a-product-site-reads): the files in `build/one-id-data/` and `lake exe oracle` |
| Review or change the model | [`Rules/OneId/`](Rules/OneId/), then [`CLAUDE.md`](CLAUDE.md) and the rest of this README |

## The method

1. **Survey before Lean.** Every rule in the scope of the project is listed in [`docs/one-id-survey.md`](docs/one-id-survey.md) with its requirement word, its section, and a grade: clear when the guide states it, vague when the guide uses an undefined term or states it twice at different strengths, silent when the guide names the situation and gives no rule. Each entry is also a node of the blueprint, so the dependencies between rules are known before any is formalized.
2. **Keep every reading.** Where the guide is vague or silent, the Lean rule takes the undecided part as a parameter, called a reading. A guarantee counts as proven only if it holds under every reading. The model never picks one.
3. **A question is a computed example.** A guarantee that some reading breaks stays open. An example written by hand shows the case under that reading, and Lean computes its result. The example states Given, When and Then in plain words, so an expert can answer the question from the example alone.
4. **Rank the questions, and tell decisions from lookups.** The progress page ranks every open question and every candidate that needs a decision by the number of blueprint cards that depend on it, directly or through other cards. The count comes from the dependency graph. A question that asks what a cited specification says is a lookup: it needs a source to be read, and it is ranked in its own list, since it goes to a reader with the document and the others go to the people who own the standard.
5. **Record where each rule comes from.** Each rule names the sections of the guide it was written from with `@[source]`, and the external specifications it relies on with `@[assumes]`. The build fails on a rule with no source. `@[confirmed]` records a confirmation from outside the model, with a fingerprint that goes out of date when the rule changes. Nothing is confirmed yet.
6. **Critique independently.** After each milestone a reviewer who has not seen the reasoning compares the survey with the guide and every criterion with its theorems.

## What is modelled

Milestone one covers the source conversion, the survey, and the credential data model of §4.1. Milestone two covers the presentation flows of §4.2: a core the three profiles share, the OpenID4VP profile from its public specifications, and the rules the guide itself states for the mdoc profile and proximity, whose ISO documents were not read. The counts below are from the build of 2026-11-05; the progress page has the current ones.

| | Count |
| --- | --- |
| Rules of the guide surveyed | 109: 43 clear, 45 vague, 21 silent |
| Requirements in Lean | 17: OID-101 to OID-109, OID-201 to OID-207, OID-301 |
| Acceptance criteria | 71: 47 proven, 24 open |
| Open questions in Lean, each with a computed example | 25, from 26 open theorems (two are the same question for the two credentials) |
| Candidates that need a decision before they can be modelled | 44 |
| Candidates that need a source to be read, and no decision | 4, with 4 of the open questions in Lean |
| Theorems proven | 71, of which 34 check a criterion; the others hold under one reading, in one profile, or support another proof |
| Dependencies on external specifications recorded | 29: 19 relied on by the model, 10 not yet modelled |
| Of those, from specifications that were read | 10, from 10 public documents; the other 19 are from documents that are sold or not public |
| Clauses of public specifications surveyed | 47, in 11 documents |

The seventeen requirements:

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
| OID-201 | What a wallet discloses in answer to a request | §3.1, §3.2, §4.2 |
| OID-202 | What a relying party checks before it accepts a response | §3.1, §3.2, §4.2 |
| OID-203 | What an OpenID4VP request must carry | §4.2.1.3 |
| OID-204 | What a wallet checks before it answers an OpenID4VP request | §4.2.1.3, §3.2 |
| OID-205 | What an OpenID4VP response is bound to | §4.2.1.3 |
| OID-206 | What a request of the mdoc profile must carry | §4.2.1.2 |
| OID-207 | Whether a photoid and a boarding pass presented together are one traveler's | §4.1.2, §3.2, §4.2.1.2 |
| OID-301 | The keys and the retrieval method of a proximity session | §4.2.2 |

The four candidate guarantees are stated in Lean, and none is proven for every profile and every reading:

| Guarantee | Proven | Open |
| --- | --- | --- |
| G-01 Only requested and consented data is received | A wallet that follows the rules discloses only what was requested and approved. A response carries no record of consent, so a relying party cannot check it. | An accepted response holds only what was requested: true in a profile only if a relying party there refuses extra data, a reading in all three profiles. |
| G-02 A presentation is bound to the device and the request | Every accepted credential is signed with the device key its issuer signed, in all three profiles, and over the session transcript of the relying party's own request in both remote profiles. In the OpenID4VP profile a response made for one origin, nonce and key is refused for any other, and two requests never share a nonce. | In the mdoc profile, whether the transcript holds the nonce, until Annex C is read. In proximity, whether the reader compares the transcript at all. |
| G-03 A photoid and a boarding pass presented together are one traveler's | One traveler follows where the device keys are compared and issuance gives each device key to one traveler. A presentation does not carry who a credential is about, so no check of it can do without a rule about issuance. | Every reading of the check, since the guide puts issuance out of scope. |
| G-04 An expired credential is never accepted | The mdoc profile. | The OpenID4VP profile, until the clause it cites is read. Proximity, until that clause is read and, if it has no validity check, until it is decided whether the clause proximity cites with should is enough. |

Signatures, keys, nonces and origins are symbolic: values that can only be compared, with the outcome of a signature check as a field. The model says what a relying party compares, and nothing about how hard a signature is to forge.

## What the guide leaves out

The guide puts the trust model, revocation and normative issuance out of scope (§1.4). They are silent entries C-01 to C-03 in the survey. The model does not fill them in. The survey lists, for each, the guarantees it blocks: a proof of one of those guarantees would need a rule the guide does not give.

## External specifications

The guide builds on ISO/IEC 18013-5, ISO/IEC TS 18013-7, ISO/IEC TS 23220-2 and 23220-4, OpenID4VP, OpenID4VC HAIP, the W3C Digital Credentials API, IATA Resolution 792, ICAO Doc 9303 and several IETF RFCs. The public ones were read (decision 22), and a statement about one of them names its clause. The ISO documents and Resolution 792 were not read, and the model takes from each of those only what the guide says about it:

- Where a rule depends on the content of an external table or format, that content is a parameter of the rule. `PhotoidTables` stands for Tables C.1 to C.3 of ISO/IEC TS 23220-4, and `Resolution792` for what IATA Resolution 792 decides about a boarding pass string. `IsoTranscripts` stands for the session transcripts that ISO/IEC TS 18013-7 Annex C and ISO/IEC 18013-5 define for the mdoc profile and proximity. A guarantee is proven only if it holds for every value of the parameter.
- Every dependency is listed once in [`Rules/Core/Assumptions.lean`](Rules/Core/Assumptions.lean) with the clause the guide cites, and a declaration that relies on one names it with `@[assumes "<key>"]`. The attribute rejects an unknown key.
- The examples need some table and some boarding pass format to compute with. [`Rules/OneId/Examples.lean`](Rules/OneId/Examples.lean) uses stand-ins that are invented and labelled as such.

## How the build turns the model into documents

People write the Lean files, the survey, the blueprint statements and the prose chapters. Everything else is computed, so no status, count, ranking or example value is typed by hand.

| Step | What it does | It fails when |
| --- | --- | --- |
| `lake build` | Checks every proof and every `#guard` | A proof is rejected, an example's value changes, or a rule names a source or an assumption that is not listed |
| `lake exe status` | Computes each theorem's and criterion's status, each rule's fingerprint and provenance; writes `build/status.json` and the CSV exports | A theorem depends on `sorry` without `@[open_question]`, a rule has no `@[source]`, an EARS statement or criterion does not follow one EARS template, a rule lacks a story or criteria, or a `@[checks]` tag names a criterion no rule defines |
| `lake exe oneid-facts` | Evaluates every scenario under every reading setting; writes `scenarios.json`, `readings.json` and `decisions.jsonl` to `build/one-id-data/`, and the same three files for the presentations to `build/one-id-data/presentation/` | A default scenario depends on a reading, a scenario disagrees with its example, the oracle answers a request differently from the model's functions, or a list in `Oracle/` or `Exports/` disagrees with the definitions it describes |
| `scripts/replay_one_id.py` | Runs every decision of both sets through `lake exe oracle` | An answer differs from the recorded response |
| `scripts/export_one_id.py` | Writes `build/one-id-data/model.json` from `build/status.json` | An open theorem has no question |
| `scripts/render_status.py` | Writes the review chapters, the blueprint's `\leanok` markers and the requirement specs | The blueprint names a declaration the build does not report, or `Review/Review.lean` misses a requirement chapter |
| `scripts/check_survey.py` | Checks the survey, the blueprint, the model and the citations against each other | A survey entry has no node and no requirement, a grade disagrees with the blueprint, a count disagrees with the rows, or a citation names a section the guide does not have |
| `lake exe review-doc` | Renders the Verso review document | A chapter names a declaration that does not exist |
| `leanblueprint web`, `checkdecls`, `pdf` | Renders the blueprint and its dependency graph | The blueprint names a Lean declaration that does not exist |
| `scripts/render_progress.py` | Writes the progress page and `build/ranking.json` | A `\uses` names a label that does not exist, or a blueprint section is not in `AREA_ORDER` |
| `scripts/render_home.py` | Writes the home page | The open question the page works through has been proven, or lost its example |
| `scripts/check-airline.sh` | Runs Verified Airline's check of its One ID pages against `build/one-id-data/`, once that repository has them | The airline's check fails |

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
| The data a product site reads: scenarios, readings, decisions and the model's requirements | `lake exe oneid-facts`, `scripts/export_one_id.py` | `/one-id-data/` |

The site is not published anywhere. The repository is private and has no remote, and GitHub Pages is not available for a private repository on this account's plan. Build it with `scripts/build-site.sh` and serve it with `python3 scripts/serve_site.py`, or do both with `scripts/preview.sh`.

## The data a product site reads

The build writes four files to `build/one-id-data/` and three more to `build/one-id-data/presentation/`, and the assembled site serves them at `/one-id-data/`. A product site, such as the One ID pages planned for [Verified Airline](https://github.com/samdengler/verified-airline), reads them instead of the Lean. Nothing in them is typed by hand: each result comes from the model's functions, each label from a Lean docstring, and each status from `build/status.json`. The top-level files cover the credential checks of §4.1, and the files in `presentation/` the presentation flows of §4.2. `model.json` lists the requirements of both.

| File | Written by | What it holds |
| --- | --- | --- |
| `scenarios.json` | `lake exe oneid-facts` | Trips a site can show: the credentials, who each is about, the journey and the instant of the check |
| `readings.json` | `lake exe oneid-facts` | Every undecided point the checks take as a parameter, with its settings, the checks that read it, and the open criteria and questions it bears on |
| `decisions.jsonl` | `lake exe oneid-facts` | Each scenario under each reading setting, as an oracle request with the model's response. These are the conformance vectors |
| `model.json` | `scripts/export_one_id.py` | Every requirement with its criteria and their statuses, the open questions, and the identifier constants |
| `presentation/scenarios.json` | `lake exe oneid-facts` | Presentations a site can show: what the wallet holds, the request it received, the consent, the relying party's request and the response it receives |
| `presentation/readings.json` | `lake exe oneid-facts` | Every undecided point the presentation rules take as a parameter, in the shape of `readings.json`, with the profiles each applies in |
| `presentation/decisions.jsonl` | `lake exe oneid-facts` | Each presentation scenario under each reading setting of its profile, and boundary vectors, in the shape of `decisions.jsonl` |

The tables and the boarding pass format every scenario uses are the invented stand-ins of [`Rules/OneId/Examples.lean`](Rules/OneId/Examples.lean), and the ISO session transcripts of the presentations those of [`Rules/OneId/PresentationExamples.lean`](Rules/OneId/PresentationExamples.lean). Each scenario says so, and a site that shows one must say so too.

### The oracle

`lake exe oracle` is the model behind JSON: one request per line on standard input, one response per line on standard output ([`Oracle/Handle.lean`](Oracle/Handle.lean)). It loads the compiled model into Lean's interpreter, as `lake exe status` does, so it does not link Mathlib. Every request names its rule, carries every input of the rule, and names its reading under `reading`:

| `rule` | Other inputs | Reading points | `result` |
| --- | --- | --- | --- |
| `Photoid.violations` | `tables`, `credential` | the six points of `PhotoidReading` other than `passportRequired` | findings |
| `Photoid.advisories` | `tables`, `source`, `credential` | none | advisories |
| `Photoid.sourceFindings` | `source` | `PhotoidReading.passportRequired` | findings |
| `Photoid.validityFindings` | `documentExpiry`, `credential` | `PhotoidValidityReading` | findings |
| `BoardingPass.violations` | `resolution792`, `credential` | the two points of `BoardingPassReading` | findings |
| `BoardingPass.validityFindings` | `journey`, `credential` | `ValidityReading.departure`, `ValidityReading.soonAfter` | findings |
| `expired` | `credential`, `now` | `ExpiryReading.validAtEnd` | true or false |
| `travelerMatch` | `resolution792`, `photoid`, `boardingPass` | `MatchReading` | true or false |

The inputs are the Lean values as JSON:

- An instant (`now`, `documentExpiry`, `validUntil` and the instants of a journey) is its epoch seconds, UTC.
- A credential is an `Mdoc`: `{"docType", "validUntil", "nameSpaces": [{"name", "elements": [{"identifier", "value"}]}]}`. A value is one of the constructors of `Value`: `{"text": "SMITH"}`, `{"bytes": [1, 2, 3]}`, `{"flag": true}` or `{"other": "43"}`.
- `tables` is a `PhotoidTables`: `{"base", "photoid", "dataGroups"}`, each `{"entries": [{"identifier", "presence", "encoding"}]}`, with `presence` one of `mandatory`, `optional`, `other` and `encoding` one of `text`, `bytes`, `flag`, `other`.
- `source` is `passport` or `other`. `journey` is `{"scheduledDeparture", "actualDeparture", "completed"}`.
- `resolution792` names a format. `Resolution792` holds functions, so it cannot travel as data. The only format is `exampleResolution792`, the invented stand-in.
- `reading` is an object whose keys are the ids of the reading points in `readings.json`, each with its setting: `true` or `false`, a number of seconds, or the name of a constructor. It holds exactly the points the rule reads. `lake exe oneid-facts` checks the list of points against the definitions of the rules, so a point a rule does not read cannot change its answer.

The response is `{"result": ...}`. A finding is the name of its constructor of `Finding` as `code`, with each argument under its Lean name: `{"code": "missingElement", "nameSpace": "org.iso.23220.1", "identifier": "portrait"}`. An advisory has the same form, from `Advisory`. A request the oracle cannot read, such as one that lacks an input or names a point its rule does not read, gets `{"failure": "..."}`.

### `scenarios.json`

```json
{"generatedBy": "lake exe oneid-facts",
 "standIns": {"invented": true,
              "tables": {"lean": "Rules.OneId.exampleTables", "value": {"base": {"entries": [...]}, ...}},
              "resolution792": {"lean": "Rules.OneId.exampleResolution792", "format": "exampleResolution792"}},
 "scenarios": [
  {"id": "accented-name",
   "title": "José María García's name has accents on the passport and none on the boarding pass",
   "default": false,
   "credentials": [{"role": "photoid", "about": "traveler 1", "mdoc": {...}},
                   {"role": "boardingPass", "about": "traveler 1", "mdoc": {...}}],
   "journey": {"scheduledDeparture": 1803895200, "actualDeparture": 1803895200, "completed": 1803902400},
   "checkedAt": 1803889800,
   "sourceDocument": {"kind": "passport", "expires": 1924992000},
   "standIns": true,
   "example": "Rules.OneId.ownBoardingPassRefused"}]}
```

`about` is the traveler the issuer issued the credential about, which a relying party does not see (decision 8). `journey` is null for a scenario without a boarding pass, and `sourceDocument`, the document a photoid was derived from, is null for one without a photoid. `example` names the `@[case]` example the scenario reproduces, and the build stops if the scenario's inputs give that example a different record. Exactly one scenario has `"default": true`, and it gives every check the same result under every reading setting. The build stops if it does not.

A site relies on two links between the files: `scenarios[].example` and `readings[].questions[].examples`. Verified Airline's site stops a trip at a reading point whose open question lists the trip's example. So the build stops if a scenario's example is not listed under a question of a reading point that one of the scenario's rules reads, unless the scenario is the default or has no example. It also stops if a credential reading point changes no answer of any rule in any scenario, since its switch on a site would then do nothing; `lake exe oneid-facts` prints, for each point, the scenarios in which it changes an answer.

### `readings.json`

```json
{"generatedBy": "lake exe oneid-facts",
 "readings": [
  {"id": "MatchReading",
   "lean": "Rules.OneId.MatchReading",
   "label": "What a relying party checks before it treats a photoid and a boarding pass as being about the same traveler.",
   "description": "...",
   "settings": [{"value": "notChecked", "label": "Nothing is checked: any photoid goes with any boarding pass.",
                 "description": "...", "lean": "Rules.OneId.MatchReading.notChecked"},
                {"value": "namesAgree", ...}],
   "asWritten": "notChecked",
   "checks": ["travelerMatch"],
   "criteria": ["OID-107.1", "OID-107.2"],
   "questions": [{"theorem": "Rules.OneId.matched_pair_same_traveler", "criteria": ["OID-107.1"],
                  "question": "What ties a photoid and a boarding pass to one traveler: ...?",
                  "examples": ["Rules.OneId.anotherTravelersBoardingPass", "Rules.OneId.twoTravelersWithOneName"]}]}]}
```

A point's `id` is its Lean name below `Rules.OneId`: a field of a reading structure, such as `PhotoidReading.portraitRequired`, or a reading type whose constructors are its settings, such as `MatchReading`. `label` is the first sentence of the docstring of that name, and `description` the whole docstring. A constructor setting takes its own docstring. A yes or no setting is labelled Yes or No, which answers a label that starts with "Whether", and a duration is written out. `asWritten` is the setting whose docstring says it is the guide as written, or null. `checks` lists the rules that read the point. `questions` lists the open theorems the point bears on, each with the last sentence of its docstring, which is its question, and the examples it quotes.

### `decisions.jsonl`

One line per scenario, check, credential and combination of the settings of the points the check reads:

```json
{"name": "accented-name travelerMatch MatchReading=namesAgree",
 "scenario": "accented-name",
 "request": {"rule": "travelerMatch", "reading": {"MatchReading": "namesAgree"},
             "resolution792": "exampleResolution792", "photoid": {...}, "boardingPass": {...}},
 "response": {"result": false}}
```

`request` is a complete oracle request, so a team with only a JSON reader can run each line through its own code and compare the answer with `response`. After the scenarios come six boundary vectors for `expired`: a boarding pass one second before, at and one second after the end of its validity, under both expiry readings. Their `scenario` is null. A site finds the decision for a scenario, a check and the reader's settings by `scenario`, `request.rule` and `request.reading`; for `expired`, the credential's `docType` says which credential it is.

### The presentation files

The files in `presentation/` have the shapes of the top-level ones, with what a presentation needs added. The oracle answers ten more rules, each named after its Lean function:

| `rule` | Requirement | Inputs besides `rule` and `reading` | Reading points |
| --- | --- | --- | --- |
| `Wallet.respond` | OID-201 | `isoTranscripts`, `held`, `seen`, `consent` | `ConsentReading` |
| `refusals` | OID-202 | `isoTranscripts`, `trustedIssuers`, `request`, `response`, `now` | the points of `AcceptanceReading` for the request's profile, and `ExpiryReading.validAtEnd` |
| `OpenId4Vp.requestFindings` | OID-203 | `authorization` | `OpenId4Vp.RequestReading.stateRequired` |
| `OpenId4Vp.reuseFindings` | OID-203 | `authorizations` | none |
| `OpenId4Vp.walletFindings` | OID-204 | `trustedVerifiers`, `seenOrigin`, `authorization` | `stateRequired` and the two points of `OpenId4Vp.WalletReading` |
| `OpenId4Vp.transcript` | OID-205 | `origin`, `nonce`, `encryptionKey` | none |
| `OpenId4Vp.tokenFindings` | OID-205 | `token`, a list of device responses, each a list of presented credentials | none |
| `MdocProfile.requestFindings` | OID-206 | `deviceRequest` | none |
| `pairRefusals` | OID-207 | those of `refusals`, with `resolution792`, `photoid` and `boardingPass` in place of `response` | those of `refusals`, and the two points of `PairReading` |
| `Proximity.sessionFindings` | OID-301 | `sessions` | none |

Keys, nonces, origins, issuers and certificates are symbolic, as in the model: `{"name": "phone"}`, `{"value": "nonce 1", "entropyBytes": 16}`, `{"value": "https://checkin.example"}`. A request is `{"profile", "origin", "nonce", "encryptionKey", "engagementKey", "elements"}`, where an element is `{"docType", "nameSpace", "identifier"}`. A presented credential is `{"mdoc", "issuer", "issuerSignatureValid", "deviceKey", "deviceSignature"}`, and a device signature `{"key", "transcript"}`. A session transcript is `{"handover": {"origin", "nonce", "encryptionKey"}}` in the OpenID4VP profile or `{"iso": "..."}` in the other two. The ISO transcripts are functions in the model, so `isoTranscripts` names one of two invented stand-ins, `exampleIsoTranscripts` or `transcriptsWithoutNonce`. Every other input is the Lean structure of the same name, with `null` for an absent optional field. Refusals and findings are a code and the constructor's arguments, as for the credential checks: `{"code": "missing", "element": {...}}`, `{"code": "refused", "reason": {"code": "expired", "docType": "org.iata.boardingpass.1"}}`.

The points `refusals` and `pairRefusals` read depend on the profile of `request`: the extra data and missing data points of the mdoc profile there, the extra data and validity points of the OpenID4VP profile, and the four points of proximity. A request holds exactly those, and each entry of `presentation/readings.json` lists the `profiles` it applies in.

A presentation scenario:

```json
{"id": "default-proximity", "profile": "proximity", "default": true,
 "title": "Alice Martin taps a phone at the gate reader and approves everything asked",
 "held": [{"mdoc": {...}, "subject": {"id": "traveler 1"}, "issuer": {"name": "Utopia passport office"},
           "deviceKey": {"name": "phone"}}, ...],
 "seen": {...}, "consent": {"approved": [...]}, "request": {...}, "response": {"documents": [...]},
 "checkedAt": 1803889800, "trustedIssuers": [...], "isoTranscripts": "exampleIsoTranscripts",
 "authorization": null, "seenOrigin": null, "trustedVerifiers": [], "deviceRequest": null,
 "sessions": [{"deviceKey": {"name": "engagement 1"}, "readerKey": {"name": "reader key 1"},
               "retrieval": "bluetoothLowEnergy"}],
 "standIns": true, "example": null}
```

`seen` is the request as the wallet received it and `request` the relying party's own; they differ when a request is relayed through another origin or a response is replayed. `response` is what the relying party receives, which a wallet that breaks the rules may have made. `authorization`, `seenOrigin` and `trustedVerifiers` are the request as it travels in the OpenID4VP profile and the wallet's view of it, `deviceRequest` the request of the mdoc profile, and `sessions` the proximity sessions of one deployment. A field a scenario does not use is null or empty, and the rules that need it are not evaluated for it. Each profile has one default presentation, Alice Martin's honest check-in, and it gives every rule the same answer under every reading setting of its profile. A scenario that reproduces an example in one profile agrees with the part of the example about that profile. After the scenarios come boundary vectors, with `scenario` null, for the rules no scenario gives a finding: two requests that share a nonce or a key, a token with two mdocs in one device response, a malformed request of the mdoc profile, and proximity sessions that break each of the three rules.

### `model.json`

The same shape as the `model.json` that verified-air's `scripts/export_airline.py` writes for Verified Airline, so the same code can show it: `source`, `requirements` keyed by ID (each with its Lean `name`, its `ears` in Kiro's notation, `review`, and `criteria` with `id`, `status` and `ears`), and `openQuestions` keyed by criterion (each with its `theorem`, the start of its `question`, and `review`). It differs in six ways:

- `source.repository` and `source.site` are null, since the repository has no remote and the site is not published.
- `source.dirty` is true when the working tree had changes at build time (`git status --porcelain` printed anything), so `source.commit`, which is HEAD at build time, does not hold everything the files were built from. Files built just before a commit name its parent and are dirty. It is null when git cannot tell.
- Every `review` is null, since the review document is served only locally.
- Each open question also has `example`, the first `@[case]` example its docstring quotes.
- `identifiers` lists the document types, namespaces and data element identifiers, each with its Lean name, its value from the build, its docstring, and for a data element the namespace that holds it.
- There is no `theorems.json` beside it. verified-air's lists a theorem for each fare fact; the scenarios here have no facts proven for every input.

### Checking a site and an implementation

`lake exe oneid-facts` stops, naming the case, if the default scenario depends on a reading, a scenario disagrees with its example, two decisions share a name, or the oracle's handler answers a request differently from the model's functions. It stops if a credential reading point changes no answer in any scenario, or a scenario's example is not listed under an open question of a point its rules read. It also stops if a list written beside the model disagrees with what it describes: the reading points of a rule with the definition of the rule, the points with the fields of the reading structures, the settings of a point with the constructors of its type, the open theorem of a point with its tag, its question and its `_of_` theorem, and the code of a finding with the name of its constructor. For the presentations it also stops if a profile's default depends on a reading, if a point of the acceptance reading changes what a relying party does in a profile and the oracle does not list it for that profile or the reverse, and if `refusals` or `pairRefusals` read the acceptance reading other than through the four functions that pick a point by profile. `scripts/replay_one_id.py` then runs every decision of both sets through `lake exe oracle`. `scripts/check-airline.sh` runs Verified Airline's own check of its One ID pages against these files, once that repository has a `model/one-id/` directory, and prints that it skipped until then.

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
scripts/fetch-sources.sh                # the public specifications into sources/external/ (not committed), and sources/external.json
python3 scripts/crosscheck_source.py    # compare with the public copy; report in build/
scripts/preview.sh                      # the documents, served at http://localhost:8000
scripts/build-site.sh                   # everything CI builds, assembled in site/
```

The model builds without the converted guide and without the fetched specifications: only the conversion, the cross-check and a new reading need the documents. `scripts/fetch-sources.sh` also needs `pdftotext` (poppler).

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
10. **Survey IDs.** C-01 to C-109 are rules, G-01 to G-04 the candidate guarantees. C-97 to C-100 were added by the critique, C-101 to C-103 when lookups were separated from decisions, and C-104 when the public specifications were read. Several requirement words of the guide share one entry when they state one rule. A Lean-backed blueprint node carries the ID of its main survey entry; the survey's Model column names the requirement for the others it covers.
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
21. **Sources are linked where they are named** (added at Sam's request). The home page's opening named IATA, One ID, the guide and the specifications and linked only Lean. It now links IATA's One ID page, the guide's public copy, the chapters for the photoid and the boarding pass, the list of assumptions, and the ranked questions. Each entry of `Rules/Core/Assumptions.lean` carries the address the guide's reference list gives for its specification, so the assumptions chapter, the requirement chapters and `assumptions.csv` link out too. The sentence about One ID follows the description on IATA's own page. The ISO addresses are catalogue pages where the documents are sold.
22. **The public specifications were read, and read status is part of the model.** The first milestone was written without any specification the guide refers to. On 2026-11-05 the public ones were fetched and the clauses the guide cites in them were read: OpenID4VP 1.0, the OpenID4VC high assurance profile 1.0, the W3C Digital Credentials draft of 16 July 2026, ICAO Doc 9303 parts 10 and 11, IATA's BCBP implementation guide, and RFCs 8949, 9052, 9180 and 5280. OpenID4VCI was fetched and only its section heading for terms checked, since the guide cites it from an informative annex. The ISO/IEC documents and Resolution 792 are sold and stay unread.
    - `scripts/fetch-sources.sh` fetches each document into `sources/external/`, which is ignored, and writes `sources/external.json`, which is committed: address, day fetched, SHA-256, the version and the copyright line the copy prints, and its section numbers and titles. The script stops if a copy no longer prints the version this project read. No text is committed, and several of the documents forbid copying, so the survey describes clauses in its own words.
    - [`docs/external-survey.md`](docs/external-survey.md) has one row for each cited clause: what the guide says about it, what it says, and whether the two agree. It found four differences: the guide requires `state`, which OpenID4VP does not define over the DC API; it says the high assurance profile's considerations take precedence over Appendix A's, and the profile points to Appendix A's; it cites the W3C draft's §3 for terms, which are in §4; and it names ICAO Part 10 without a reference entry. No cited clause is missing from the copies read.
    - Each entry of `Rules/Core/Assumptions.lean` has a `read` field: read, with the name of the fetched document, or not read, with the reason. The statements of the ten read entries were rewritten from the text, each with its clause. The review document, the specs and the home page say which is which, and `assumptions.csv` exports it.
    - `scripts/check_survey.py` now fails on a clause that the copy read does not have, wherever the external survey, a read assumption, the survey or the blueprint cites one, and on an assumption whose read status disagrees with the fetched documents. The gate was tested by citing a clause that does not exist.
    - Of the nine questions marked as answered by reading a clause, one was settled. C-72 asked whether `state` is required and what the minimum entropy of the nonce is. OpenID4VP answers the first (no) and gives no number for the second, so C-72 is now a decision about entropy. C-102, what a boarding pass string contains, stays a lookup: the public guide gives the kinds of item and says the passenger name is mandatory, and leaves the list of items to the resolution's attachments. The other seven wait on ISO documents.
    - One entry was added, C-104: the public guide says some airlines issue one boarding pass for an adult with an infant, and the One ID guide does not say whether a credential may cover two travelers. It blocks G-03.
    - `PhotoidTables` and `Resolution792` stay parameters. No definition was added from a read document: the two a rule depends on are still in documents that were not read.
    - The addresses differ in one case worth knowing. The address the guide gives for OpenID4VP holds the latest revision with errata, and on the day of reading it differed from the approved text in one reference line.
23. **Presentation is modelled symbolically.** A key, a nonce and an origin are values that can only be compared. Whether an issuer's signature verifies is a field of the presented credential, and a device signature is the key that made it and the session transcript it was made over. The OpenID4VP transcript keeps the origin, the nonce and the key where the specification hashes them (OpenID4VP §B.2.6.2), so two inputs with one hash are not modelled. There is no attacker in the model: a theorem says what a relying party that makes the guide's comparisons can conclude.
24. **One core for three profiles, with the differences as readings.** A request, a consent, a response and a decision are defined once (`Rules/OneId/Exchange.lean`, `Presentation.lean`). The three profiles require issuer authentication, issuer data authentication and mdoc authentication alike. They differ on whether the response is compared with the request, whether validity is checked, and whether extra data is refused, and `AcceptanceReading` holds those. The OpenID4VP profile is written from its public specifications. For the mdoc profile and proximity the model has the rules the guide itself states, and takes the session transcript the ISO documents define as a parameter with no assumption about its content.
25. **A relying party's decision does not run the data model checks of §4.1.** With selective disclosure a relying party sees only what it requested, so it cannot tell whether a credential holds every mandatory data element, and the guide's lists of a relying party's checks hold no such step. The decision checks the issuer, the signatures, the validity and the request. Whether a relying party checks anything of §4.1 is the new survey entry C-107.
26. **Candidates the Lean covers were folded into Lean-backed nodes.** Eighteen candidate nodes of the remote and proximity areas were replaced by ten definition nodes with their theorems, and every dependency on a folded node now points at the node that replaced it. Five dependencies were dropped because they would have made a cycle: C-61, C-65, C-78 and C-88 no longer depend on the relying party's decision, which now depends on them, and C-72 no longer depends on the OpenID4VP request. The shared nodes depend only on decisions that bear on every profile: the wallet's answer does not inherit the dependencies of one profile's consent step, and the session transcript does not inherit those of the OpenID4VP request, so the ranking does not count a profile's decision against the other two. G-01 to G-04 each carry the open theorem that states them.
27. **Two regrades and three new entries.** C-73, the wallet's checks of an OpenID4VP request, went from vague to clear: the guide introduces the list with should, and the specification it makes mandatory was read as requiring the origin check and the signature and chain check of a wallet (OpenID4VP §A.2, §5.9.3). The critique showed that §5.9.3 leaves the signature check over the DC API to the wallet, and C-73 is vague again (decision 31). C-76 went from clear to vague: "matches the query" does not say whether a response with more than was asked is refused. C-105 (partial consent), C-106 (the same device key for both credentials) and C-107 are new.
28. **Not modelled in this milestone.** Encryption and decryption; error structures and codes (C-66, C-79); the entropy of a nonce, which is taken as given; reader authentication in the mdoc profile and proximity (C-55, C-57, C-84, C-85); the trusted authorities query (C-71); feature detection and the choice of protocol (C-45, C-46); the end of a proximity session (C-91); and the hand-off to the identity management system (C-67). The critique added the check that a nonce and a key are new for each request and the check of a response that lacks something requested (decision 31).
29. **The milestone tag waits for the critique.** The presentation rules are committed without `milestone/presentation-flows`. An independent reviewer compares every criterion with its theorems and the survey with the guide first, and the tag follows the fixes.
30. **The model exports data for a product site** (package 1, at Sam's request). Verified Airline's repository will show One ID pages from the model, as it shows verified-air's fares. The build now writes the four files described in [The data a product site reads](#the-data-a-product-site-reads), and ports the test oracle that decision 2 left behind. Nothing under `Rules/` changed.
    - The split follows verified-air's: an `Oracle` library with `lake exe oracle`, and an `Exports` library with `lake exe oneid-facts`, which plays the part of `airline-facts`. Both load the compiled model into Lean's interpreter. Their namespaces are outside `Rules`, so the status counts and the specs do not include them.
    - The scope is the eight credential checks of milestone one. `model.json` lists every requirement, the presentation flows included, and the presentation flows have no decisions.
    - A decision is made for every combination of the settings of the points its check reads. A site can then show any combination a reader picks, and the default trip is checked against all of them. A request carries only the points its rule reads, and the oracle refuses any other. The list of points for each rule is written in `Oracle.rules`, and `lake exe oneid-facts` compares it with the constants the rule's definition uses, following the definitions it calls, so a point that cannot change an answer is never asked for.
    - "Soon after" has the settings 0 seconds, an hour and a day. The guide gives no limit, so any list is a sample; the examples use an hour and a day, and 0 is the guide's "on" departure.
    - Labels come from docstrings. A yes or no point has no docstring for each setting, so its settings are labelled Yes and No, which answer the point's label, a sentence that starts with "Whether". The open theorems each point bears on are listed by hand in `Exports/Readings.lean`, since the names of the `_of_` theorems do not always name the point (`photoid_only_listed_of_closed`). The executable checks each link: the theorem is open and tagged, its docstring ends with a question, and its `_of_` theorem, where there is one, mentions the point. It also fails on an open theorem of a credential rule that no point names.
    - The default trip, Alice Martin with her own boarding pass before a 10:00 departure, was built so that no undecided point matters: a portrait, no data the guide does not list, no data group 2, no recommended namespace, a passport that expires after the photoid, a flight on time, a boarding pass that ends at departure, and a check before departure. `CLAUDE.md` makes that a rule, and the build enforces it.
    - The other eleven scenarios reproduce `@[case]` examples. The examples build their inputs inside their own definitions, so the scenarios rebuild them with the same builders, and the build recomputes each example's record from the scenario's inputs and compares it with the example's value. A pair of credentials and a photoid alone have no journey or instant in their examples; they take the default trip's.
    - The codes of findings and advisories are the names of their constructors, and their fields the names of the arguments. The executable builds each constructor and checks the oracle's JSON for it, so a renamed constructor stops the build.
    - The boundary vectors for `expired` use the boarding pass of the examples and belong to no scenario.
    - `scripts/check-airline.sh` follows verified-air's script, except that it does not clone the airline's repository: it skips until a checkout next to this one has `model/one-id/`. The name of the check it then runs, `scripts/check_one_id.py --model <directory>`, is a guess, since the airline's repository has no One ID pages yet; change it when they exist.
    - The files are copied into the assembled site at `/one-id-data/`. The site is still not published, so the airline's repository will take them from a local build.
31. **Fixes from the critique of the presentation flows.** A reviewer who had not seen the reasoning compared every criterion of OID-201 to OID-207 and OID-301 with its theorems, the survey's entries for §4.2 with the guide, and every statement about a public specification with the fetched text. It found 17 problems. All were acted on before the milestone tag:
    - OID-204 took all four of a wallet's checks as required because OpenID4VP was said to require the signature check (§5.9.3). That clause leaves the signature check over the DC API to the wallet. `WalletReading` now holds whether a wallet validates the signature and whether it checks its list of trusted verifiers; OID-204.2 and OID-204.3 are open, each with an example and a proven version for its reading, OID-204.1 (the origin, OpenID4VP §A.2) stays proven, and C-73 is vague again. The external survey's row for §5.9.3 and decision 27 were corrected.
    - A relying party never refused a response that lacked a requested data element, so an empty response was accepted, against OpenID4VP §8.6, which the guide makes a must. The refusal is now required in the OpenID4VP profile and a reading in the two ISO profiles (OID-202.7, open, example `partialResponse`). `wallet_response_accepted` now holds for a response that has every requested data element, and `wallet_response_refused_only_for_missing` says what it covers otherwise.
    - The reading that a relying party in the mdoc profile does not compare the session transcript contradicted the guide, which requires mdoc authentication with that transcript to prevent replay, the kind of statement that settled G-04 for that profile. The comparison is now fixed for both remote profiles. What the transcript contains stays an assumption and a lookup: `MdocProfile.accepted_for_one_nonce` is open with the example `nonceOutsideTheTranscript`, and holds where the transcript determines the nonce. C-65 is vague and its extra-data half is the new entry C-108.
    - The replay example gave the later request a new encryption key, so its result depended on decryption, which is not modelled. The later request now differs only in its nonce. Proximity has its own example, `replayedInProximity`.
    - Refusing extra data was one reading for three profiles whose texts differ. It is now a reading for each profile, and the question offers discarding the credential, which OpenID4VP §8.6 prescribes for a presentation that fails a check. The model still refuses the whole response for a reason found in one credential, and says so.
    - OID-205.4 was proven by a definition that could not fail. A token is now a list of device responses, and a relying party refuses one that holds more than one mdoc (HAIP §5.3.1, which the guide's opening of §4.2.1.3 makes a must for both parties).
    - OID-203 checked that a nonce and a key were present, not that they were new. `reuseFindings` refuses two requests of one relying party that share either (OID-203.7, OID-203.8).
    - An assumption said issuer data authentication covers validity for every clause the guide cites. It now gives the guide's words for each clause, and six statuses that still said not yet modelled were brought up to date.
    - Survey entry C-88 applied should to rebuilding the transcript and said it was taken as must, while the Lean keeps it as a reading. The entry, the reading and the question now say what the guide says, including that a verifier needs to perform the listed checks.
    - The per-element consent reading also let a wallet send a credential that lacks a requested data element. That case does not depend on consent: in the OpenID4VP profile the wallet now sends nothing of such a credential (OpenID4VP §6.4.1), and in the ISO profiles it sends what it holds.
    - The validity check is now a reading for the OpenID4VP profile and for proximity separately, since proximity also cites the mdoc profile's clause with should. G-04's card no longer mixes the lookup with the decision; the lookup stays on C-101.
    - `twoTravelersOneDevice` now says the names are not compared, and the pair examples return no result when the wallet presents fewer than two credentials, so a guard cannot pass on nothing.
    - `no_check_shows_consent` and `no_presentation_check_identifies_the_traveler` are described as following from what a response carries, not as properties of the checks.
    - `_of_` names are kept for one reading. The versions for one profile are named `_in_<profile>`, and the pair theorem that also needs a rule about issuance is `accepted_pair_same_traveler_if_one_traveler_per_key`, so the progress page does not show them under "If we decide this".
    - OID-201's text says that holder authentication, which §3.2 requires, is not modelled.
    - C-12 now names OID-201 and the two texts its reading follows (§4.1.1, OpenID4VP §6.4).
    - The header of the presentation theorems named the wrong module for its examples.

    The reviewer could not verify anything inside the ISO documents, and did not run the build.
32. **The presentation flows are exported as well** (the model half of package 6, at Sam's request). The build now writes scenarios, readings and decisions for the presentation rules to `build/one-id-data/presentation/`, described in [The presentation files](#the-presentation-files). The top-level files keep exactly their content and shape, since Verified Airline's check fails if `readings.json` gains a point or `decisions.jsonl` a line its code cannot answer. Nothing under `Rules/` changed.
    - The oracle answers ten presentation rules, one for each function a product would run, under its Lean name: what a wallet sends (OID-201), the relying party's refusals of a response and of a pair (OID-202, OID-207), the OpenID4VP request's findings and its reuse of nonces and keys (OID-203), the wallet's findings on a request (OID-204), the transcript and the token's findings (OID-205), the mdoc profile request's findings (OID-206) and the proximity sessions' findings (OID-301). They are in `Oracle/Presentation.lean`; `lake exe oracle` answers both kinds of request.
    - The reading points a relying party reads depend on the profile, since each point of `AcceptanceReading` is stated for the profiles whose text leaves it open. A request carries the points of its own profile only, so the decisions vary three points in the OpenID4VP profile and the mdoc profile and five in proximity, where the full product would vary nine everywhere. The build checks the lists two ways. It tries every acceptance reading with each point flipped, and lists the points that change one of the four functions that pick a point by profile; that list must equal the oracle's for each profile. And it follows the definitions of `refusals` and `pairRefusals`, stopping at those four functions, and fails if any other path reaches a point of the acceptance reading.
    - The default presentation is Alice Martin's honest check-in, once in each profile, with the same photoid and boarding pass as the default trip on one phone. It does not depend on a reading in any profile, so all three are marked default. Two choices make that so. The OpenID4VP request carries a state value, which both readings of the guide's sentence on state accept; without one, `OpenId4Vp.requestFindings` and `OpenId4Vp.walletFindings` would find a missing state under the reading that the guide's must is meant. And the check is at 08:30, before the boarding pass's validity ends at departure, so neither the validity readings nor the reading of the instant the validity ends can matter.
    - The other eighteen scenarios reproduce the presentation examples. Where an example compares profiles (the partial response, the replay, the expired boarding pass), there is one scenario for each profile it names, and each agrees with the part of the example about its profile. The nonce outside the transcript is the mdoc replay with the other ISO stand-in. `MdocProfile.accepted_for_one_nonce` checks no criterion and bears on the ISO transcripts, which are an external parameter, so no reading point names it.
    - A scenario holds the response the relying party receives as data. Most come from `Wallet.respond` under the consent reading the example uses; the extra element is the hand-built response of a wallet that breaks the rules. The decisions of `Wallet.respond` show what a wallet sends under each consent reading beside it.
    - The ISO transcripts are functions in the model, so a request names one of the two stand-ins, as it names the boarding pass format. A scenario that has the request as it travels, in the OpenID4VP profile or the mdoc profile, is checked to have the relying party's request as its shared form.
    - The rules no scenario gives a finding have boundary vectors instead: shared nonces and keys, a token with two mdocs in one device response, a malformed mdoc profile request, and proximity sessions that break each rule. The codes of refusals and findings are checked against their constructors as before; arguments that are not strings are built from the types' default values.
33. **A scenario for every credential example, and a switch that always does something** (at Sam's request). Verified Airline reported that six of the fourteen credential reading points changed no result in any scenario, so their switches did nothing. Measured on the decisions, five changed no answer: the five photoid points whose examples had no scenario. Those five examples that had no scenario now have one each, built from the example's own inputs: data no table lists, a portrait that differs from data group 2, an incomplete photoid namespace, an incomplete data groups namespace, and a repeated family name. `lake exe oneid-facts` now finds, for each credential reading point, two decisions of one case whose readings differ in that point alone and whose answers differ, and stops if a point has none; every point has one. It also stops if a scenario's example is not listed under an open question of a reading point its rules read, the link the site uses to stop a trip at a reading. The two checks apply to the credential scenarios only; the presentation files are unchanged.
34. **Which departure is meant changes no result a relying party computes, and is left as a question** (at Sam's request). `expiredBeforeADelayedDeparture` showed one side of the departure reading: under the scheduled reading, a traveler on a delayed flight holds an expired boarding pass. The new example `signedAgainAfterADelay` shows the other: the same flight, and a boarding pass the airline signed again to end at 14:00, an hour after the actual departure. With "soon after" an hour, its validity breaks no requirement if the actual departure is meant and ends long after the departure if the scheduled one is. At 12:30 it is not expired under either reading, because `expired` reads only the credential's end of validity and the instant. OID-104 is a duty of the issuer, and the only time check the guide gives a relying party is that a credential is within its validity (C-44), which the model states as expiry (OID-105). So for one credential a relying party gives the same answer under both readings. The model adds no check of the validity against the journey for a relying party: the guide states none, and the departure is an input of the issuer's rule and not in the credential (decision 8). Whether a relying party must refuse a boarding pass whose validity does not fit the journey is the new silent entry C-109. The example has the scenario `signed-again-after-delay`, and the open question of `ValidityReading.departure` quotes it, so a site stops that trip at the departure reading.
