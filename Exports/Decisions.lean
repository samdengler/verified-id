import Exports.Scenarios
import Exports.Readings

set_option doc.verso false

/-!
# Decisions

Every scenario evaluated by the model's functions, under every combination of
the settings of the reading points each check reads.  Each decision is a
complete oracle request with the model's response, so the list is also the set
of conformance vectors: a team with only a JSON reader runs each request
through its own code and compares.  Boundary vectors for `expired` follow: one
second before, at and after the end of a boarding pass's validity, under both
expiry readings.

`decisionLines` stops, with a message that names the case, if the default
scenario's result for a check differs between two reading settings, if a
scenario disagrees with the example it reproduces, if two decisions share a
name, or if the oracle answers a request differently from the model's
functions.
-/

open Lean Rules.Core Rules.OneId Oracle

namespace Exports

/-- One decision of the model. -/
structure Decision where
  /-- The scenario, the check and the credential: decisions of one case differ
  only in their reading. -/
  case : String
  /-- The scenario, or none for a boundary vector. -/
  scenario : Option String
  /-- A complete oracle request. -/
  request : Json
  /-- The model's response. -/
  response : Json

/-- The reading of a request as text: each point and its setting. -/
def Decision.settings (d : Decision) : String :=
  match d.request.getObjVal? "reading" >>= Json.getObj? with
  | .ok obj => " ".intercalate (obj.toList.map fun (k, v) =>
      s!"{k}={match v with | .str s => s | v => v.compress}")
  | .error _ => ""

def Decision.name (d : Decision) : String :=
  if d.settings.isEmpty then d.case else d.case ++ " " ++ d.settings

def Decision.json (d : Decision) : Json :=
  Json.mkObj [("name", toJson d.name),
    ("scenario", match d.scenario with | some s => toJson s | none => Json.null),
    ("request", d.request), ("response", d.response)]

/-- The settings of a reading type that differ in the points a rule reads, the
first of each kind. -/
def distinctFor {α : Type} (rule : String) (encode : α → List (String × Json)) (xs : List α) : List α :=
  let points := (pointsOf rule).toOption.getD []
  let key (a : α) : Json := Json.mkObj ((encode a).filter (points.contains ·.1))
  xs.foldl (fun acc a => if acc.any (key · == key a) then acc else acc ++ [a]) []

/-- The name of the boarding pass format the scenarios use, the invented
stand-in. -/
def format : String := "exampleResolution792"

/-- Every decision for one scenario: each check its inputs allow, under every
setting of the points the check reads. -/
def decisionsOf (s : Scenario) : List Decision :=
  let d (case : String) (req resp : Json) : Decision := ⟨s!"{s.id} {case}", some s.id, req, resp⟩
  let t := exampleTables
  let photoid : List Decision := match s.photoid with
    | none => []
    | some p =>
      let m := p.mdoc
      (distinctFor "Photoid.violations" photoidPoints photoidReadings).map (fun r =>
        d "Photoid.violations" (photoidViolationsRequest r t m) (findingsResult (Photoid.violations r t m))) ++
      (match s.derivedFrom with
       | none => []
       | some src =>
         [d "Photoid.advisories" (photoidAdvisoriesRequest t src.kind m)
            (advisoriesResult (Photoid.advisories t src.kind m))] ++
         (distinctFor "Photoid.sourceFindings" photoidPoints photoidReadings).map (fun r =>
           d "Photoid.sourceFindings" (photoidSourceRequest r src.kind)
             (findingsResult (Photoid.sourceFindings r src.kind))) ++
         photoidValidityReadings.map fun r =>
           d "Photoid.validityFindings" (photoidValidityRequest r src.expires m)
             (findingsResult (Photoid.validityFindings r src.expires m))) ++
      expiryReadings.map fun e =>
        d "expired photoid" (expiredRequest e m s.checkedAt) (boolResult (expired e m s.checkedAt))
  let boardingPass : List Decision := match s.boardingPass with
    | none => []
    | some b =>
      let m := b.mdoc
      (distinctFor "BoardingPass.violations" boardingPassPoints boardingPassReadings).map (fun r =>
        d "BoardingPass.violations" (boardingPassViolationsRequest r format m)
          (findingsResult (BoardingPass.violations r exampleResolution792 m))) ++
      (match s.journey with
       | none => []
       | some j =>
         validityReadings.map fun v =>
           d "BoardingPass.validityFindings" (boardingPassValidityRequest v j m)
             (findingsResult (BoardingPass.validityFindings v j m))) ++
      expiryReadings.map fun e =>
        d "expired boardingPass" (expiredRequest e m s.checkedAt) (boolResult (expired e m s.checkedAt))
  let pair : List Decision := match s.photoid, s.boardingPass with
    | some p, some b =>
      matchReadings.map fun r =>
        d "travelerMatch" (travelerMatchRequest r format p.mdoc b.mdoc)
          (boolResult (travelerMatch r exampleResolution792 p.mdoc b.mdoc))
    | _, _ => []
  photoid ++ boardingPass ++ pair

/-- `expired` for a boarding pass one second before, at and one second after
the end of its validity, under both expiry readings. -/
def boundaryDecisions : List Decision :=
  let m := boardingPassOf "SMITH/JOHN"
  let ends := m.validUntil.epochSeconds
  [(ends - 1, "one second before the end of validity"), (ends, "at the end of validity"),
   (ends + 1, "one second after the end of validity")].flatMap fun (now, label) =>
    expiryReadings.map fun e =>
      ⟨s!"boundary expired boardingPass {label}", none, expiredRequest e m ⟨now⟩, boolResult (expired e m ⟨now⟩)⟩

def decisions : List Decision := scenarios.flatMap decisionsOf ++ boundaryDecisions

/-- Nothing, or the first case of the default scenario whose result differs
between two reading settings. -/
def readingFree (ds : List Decision) : Except String Unit := do
  for a in ds do
    for b in ds do
      if a.case == b.case && a.response != b.response then
        throw s!"the default scenario depends on a reading: {a.case} gives {a.response.compress} under \
          {a.settings} and {b.response.compress} under {b.settings}"

/-- The first item that occurs twice, if one does. -/
def firstRepeat (xs : List String) : Option String :=
  (xs.zipIdx.find? fun (x, i) => (xs.take i).contains x).map (·.1)

/-- The rule of a decision. -/
def Decision.rule (d : Decision) : String := (d.request.getObjValAs? String "rule").toOption.getD ""

/-- The reading of a decision as a list of points and settings. -/
def Decision.points (d : Decision) : List (String × Json) :=
  ((d.request.getObjVal? "reading" >>= Json.getObj?).toOption.map (·.toList)).getD []

/-- Runs of consecutive decisions of one case. -/
def byCase (ds : List Decision) : List (List Decision) :=
  (ds.foldl (fun (acc : Array (List Decision)) d =>
    match acc.back? with
    | some g@(e :: _) => if e.case == d.case then acc.pop.push (g ++ [d]) else acc.push [d]
    | _ => acc.push [d]) #[]).toList

/-- For each credential reading point, the scenarios in which it changes the
answer of some rule: two decisions of one case whose readings differ in that
point alone and whose responses differ. -/
def pointCoverage : List (String × List String) :=
  let changes : List (String × String) := (byCase (decisions.filter (·.scenario.isSome))).flatMap fun g =>
    g.flatMap fun a => g.filterMap fun b =>
      let differ := a.points.filter fun (k, v) => b.points.lookup k != some v
      match differ, a.scenario with
      | [(k, _)], some sc => if a.points.length == b.points.length && a.response != b.response then some (k, sc) else none
      | _, _ => none
  points.map fun p => (p.id, (changes.filterMap fun (k, sc) => if k == p.id then some sc else none).eraseDups)

/-- The rules a scenario's decisions evaluate, by scenario id. -/
def scenarioRules : List (String × List String) :=
  scenarios.map fun s => (s.id, ((decisionsOf s).map (·.rule)).eraseDups)

/-- The decisions as JSON lines, once every check passes. -/
def decisionLines : Except String (List String) := do
  match scenarios.filter (·.isDefault) with
  | [s] => readingFree (decisionsOf s)
  | ss => throw s!"there must be one default scenario, and there are {ss.length}"
  for s in scenarios do exampleAgrees s
  -- Every reading point changes some answer, so no switch on a site does nothing.
  let uncovered := pointCoverage.filterMap fun (id, scs) => if scs.isEmpty then some id else none
  unless uncovered.isEmpty do
    throw s!"these credential reading points change no answer of any rule in any scenario: {uncovered}"
  if let some id := firstRepeat (scenarios.map (·.id)) then throw s!"two scenarios have the id {id}"
  if let some n := firstRepeat (decisions.map (·.name)) then throw s!"two decisions have the name {n}"
  for d in decisions do
    match respond d.request with
    | .ok r =>
      if r != d.response then
        throw s!"the oracle answers {d.name} with {r.compress}, and the model's functions with {d.response.compress}"
    | .error e => throw s!"the oracle cannot read the request of {d.name}: {e}"
  return decisions.map (·.json.compress)

/-- The scenarios as one JSON document. -/
def scenariosJson : Json :=
  Json.mkObj [("generatedBy", toJson "lake exe oneid-facts"), ("standIns", standInsJson),
    ("scenarios", Json.arr (scenarios.map (·.json)).toArray)]

/-- The examples the scenarios reproduce, by scenario id. -/
def scenarioExamples : List (String × Name) :=
  scenarios.filterMap fun s => s.reproduces.map (s.id, ·)

/-- The identifier constants a product site may use, by kind: each one's Lean
name and, for a data element, the namespace that holds it. -/
def identifierTable : List (String × List (Name × Option Name)) :=
  [("docTypes", [(``photoidDocType, none), (``boardingPassDocType, none)]),
   ("nameSpaces", [(``baseNameSpace, none), (``photoidNameSpace, none), (``dataGroupsNameSpace, none),
     (``bcbpNameSpace, none)]),
   ("dataElements", [(``familyNameId, some ``baseNameSpace), (``givenNameId, some ``baseNameSpace),
     (``portraitId, some ``baseNameSpace), (``enrolmentPortraitId, some ``photoidNameSpace),
     (``dg2Id, some ``dataGroupsNameSpace), (``bcbpStringId, some ``bcbpNameSpace)])]

end Exports
