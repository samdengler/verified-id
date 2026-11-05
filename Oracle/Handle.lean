import Lean.Data.Json
import Rules.OneId.Examples

set_option doc.verso false

/-!
# Test oracle

The credential checks of the model behind a JSON interface, so an
implementation in another language can be checked against them.
`lake exe oracle` reads one request per line on standard input and writes one
response per line.  A request names the rule, carries every input of the rule,
and names the reading under `reading`, keyed by reading point:

    {"rule": "expired", "reading": {"ExpiryReading.validAtEnd": true},
     "credential": {...}, "now": 1803895200}

The response is `{"result": ...}`: a list of findings or advisories, or a
yes or no answer.  A request the oracle cannot read gets
`{"failure": message}`.

The rules, their Lean functions and the reading points each one reads are in
`rules`.  A request's `reading` holds exactly the points its rule reads.
`lake exe oneid-facts` checks that list against the definitions of the rules,
so a point a rule does not read cannot change its answer.

`PhotoidTables` is data and travels in the request.  `Resolution792` holds
functions, so a request names a format instead: the only one is
`exampleResolution792`, the invented stand-in in `Rules/OneId/Examples.lean`.
-/

open Lean Rules.Core Rules.OneId

namespace Oracle

/-! ## The model's types as JSON -/

/-- An instant is sent as its epoch seconds. -/
instance : ToJson Instant := ⟨fun i => toJson i.epochSeconds⟩
instance : FromJson Instant := ⟨fun j => (⟨·⟩) <$> fromJson? j⟩

/-- A value is an object with one key, the name of its encoding:
`{"text": "SMITH"}`, `{"bytes": [1, 2, 3]}`, `{"flag": true}` or
`{"other": "43"}`. -/
instance : ToJson Value where
  toJson
    | .text s => Json.mkObj [("text", toJson s)]
    | .bytes b => Json.mkObj [("bytes", toJson b)]
    | .flag b => Json.mkObj [("flag", toJson b)]
    | .other d => Json.mkObj [("other", toJson d)]

instance : FromJson Value where
  fromJson? j := do
    let obj ← j.getObj?
    match obj.toList with
    | [("text", v)] => .text <$> fromJson? v
    | [("bytes", v)] => .bytes <$> fromJson? v
    | [("flag", v)] => .flag <$> fromJson? v
    | [("other", v)] => .other <$> fromJson? v
    | _ => throw "a value is an object with one key: text, bytes, flag or other"

deriving instance ToJson, FromJson for DataElement, NameSpace, Mdoc, Presence, Encoding,
  TableEntry, ElementTable, PhotoidTables, SourceDocument, Journey, DepartureReading,
  MatchReading, PhotoidValidityReading

/-- A finding: the name of its constructor as `code`, and each argument under
its name in the Lean. -/
def findingJson : Finding → Json
  | .wrongDocType expected found =>
    Json.mkObj [("code", "wrongDocType"), ("expected", toJson expected), ("found", toJson found)]
  | .repeatedName => Json.mkObj [("code", "repeatedName")]
  | .missingNameSpace name => Json.mkObj [("code", "missingNameSpace"), ("name", toJson name)]
  | .missingElement nameSpace identifier =>
    Json.mkObj [("code", "missingElement"), ("nameSpace", toJson nameSpace), ("identifier", toJson identifier)]
  | .notText nameSpace identifier =>
    Json.mkObj [("code", "notText"), ("nameSpace", toJson nameSpace), ("identifier", toJson identifier)]
  | .wrongEncoding nameSpace identifier =>
    Json.mkObj [("code", "wrongEncoding"), ("nameSpace", toJson nameSpace), ("identifier", toJson identifier)]
  | .notFromPassport => Json.mkObj [("code", "notFromPassport")]
  | .notResolution792 => Json.mkObj [("code", "notResolution792")]
  | .unlistedNameSpace name => Json.mkObj [("code", "unlistedNameSpace"), ("name", toJson name)]
  | .unlistedElement nameSpace identifier =>
    Json.mkObj [("code", "unlistedElement"), ("nameSpace", toJson nameSpace), ("identifier", toJson identifier)]
  | .portraitDiffersFromDg2 => Json.mkObj [("code", "portraitDiffersFromDg2")]
  | .endsBeforeLastDeparture => Json.mkObj [("code", "endsBeforeLastDeparture")]
  | .endsLongAfterLastDeparture => Json.mkObj [("code", "endsLongAfterLastDeparture")]
  | .outlivesSourceDocument => Json.mkObj [("code", "outlivesSourceDocument")]

/-- An advisory, in the same form as a finding. -/
def advisoryJson : Advisory → Json
  | .missingRecommendedNameSpace name =>
    Json.mkObj [("code", "missingRecommendedNameSpace"), ("name", toJson name)]
  | .missingRecommendedElement nameSpace identifier =>
    Json.mkObj [("code", "missingRecommendedElement"), ("nameSpace", toJson nameSpace),
      ("identifier", toJson identifier)]
  | .notDerivedFromPassport => Json.mkObj [("code", "notDerivedFromPassport")]

/-- The answer of a rule that lists findings. -/
def findingsResult (fs : List Finding) : Json := Json.mkObj [("result", Json.arr (fs.map findingJson).toArray)]

/-- The answer of a rule that lists advisories. -/
def advisoriesResult (as : List Advisory) : Json :=
  Json.mkObj [("result", Json.arr (as.map advisoryJson).toArray)]

/-- The answer of a rule that says yes or no. -/
def boolResult (b : Bool) : Json := Json.mkObj [("result", toJson b)]

/-! ## Readings as JSON

Each undecided point is a key of a request's `reading`, named by its place in
the Lean below `Rules.OneId`: a field of a reading structure, or a reading
type whose constructors are its settings. -/

/-- The points of a photoid reading. -/
def photoidPoints (r : PhotoidReading) : List (String × Json) :=
  [("PhotoidReading.portraitRequired", toJson r.portraitRequired),
   ("PhotoidReading.unlistedDataAllowed", toJson r.unlistedDataAllowed),
   ("PhotoidReading.portraitIsDg2", toJson r.portraitIsDg2),
   ("PhotoidReading.photoidTableBinds", toJson r.photoidTableBinds),
   ("PhotoidReading.dataGroupsTableBinds", toJson r.dataGroupsTableBinds),
   ("PhotoidReading.repeatedNamesRefused", toJson r.repeatedNamesRefused),
   ("PhotoidReading.passportRequired", toJson r.passportRequired)]

/-- The points of a boarding pass reading. -/
def boardingPassPoints (r : BoardingPassReading) : List (String × Json) :=
  [("BoardingPassReading.unlistedDataAllowed", toJson r.unlistedDataAllowed),
   ("BoardingPassReading.repeatedNamesRefused", toJson r.repeatedNamesRefused)]

/-- The point of an expiry reading. -/
def expiryPoints (e : ExpiryReading) : List (String × Json) :=
  [("ExpiryReading.validAtEnd", toJson e.validAtEnd)]

/-- The points of a validity reading for a boarding pass. -/
def validityPoints (v : ValidityReading) : List (String × Json) :=
  [("ValidityReading.departure", toJson v.departure), ("ValidityReading.soonAfter", toJson v.soonAfter)]

/-- The point of a matching reading. -/
def matchPoints (r : MatchReading) : List (String × Json) := [("MatchReading", toJson r)]

/-- The point of a photoid validity reading. -/
def photoidValidityPoints (r : PhotoidValidityReading) : List (String × Json) :=
  [("PhotoidValidityReading", toJson r)]

/-! ## The rules -/

/-- Each rule the oracle answers: its name in a request, its Lean function,
and the reading points it reads. -/
def rules : List (String × Name × List String) :=
  [("Photoid.violations", ``Photoid.violations,
     ["PhotoidReading.portraitRequired", "PhotoidReading.unlistedDataAllowed",
      "PhotoidReading.portraitIsDg2", "PhotoidReading.photoidTableBinds",
      "PhotoidReading.dataGroupsTableBinds", "PhotoidReading.repeatedNamesRefused"]),
   ("Photoid.advisories", ``Photoid.advisories, []),
   ("Photoid.sourceFindings", ``Photoid.sourceFindings, ["PhotoidReading.passportRequired"]),
   ("Photoid.validityFindings", ``Photoid.validityFindings, ["PhotoidValidityReading"]),
   ("BoardingPass.violations", ``BoardingPass.violations,
     ["BoardingPassReading.unlistedDataAllowed", "BoardingPassReading.repeatedNamesRefused"]),
   ("BoardingPass.validityFindings", ``BoardingPass.validityFindings,
     ["ValidityReading.departure", "ValidityReading.soonAfter"]),
   ("expired", ``expired, ["ExpiryReading.validAtEnd"]),
   ("travelerMatch", ``travelerMatch, ["MatchReading"])]

/-- The reading points a rule reads. -/
def pointsOf (rule : String) : Except String (List String) :=
  match rules.find? (·.1 == rule) with
  | some (_, _, ps) => pure ps
  | none => throw s!"unknown rule {rule}; the rules are {", ".intercalate (rules.map (·.1))}"

/-- The formats of a boarding pass string a request may name.  The only one is
the invented stand-in; the real Resolution 792 is not modelled. -/
def formats : List (String × Resolution792) := [("exampleResolution792", exampleResolution792)]

/-- A request for a rule: its reading, cut to the points the rule reads, and
its inputs. -/
def request (rule : String) (reading : List (String × Json)) (inputs : List (String × Json)) : Json :=
  let points := (pointsOf rule).toOption.getD []
  Json.mkObj ([("rule", toJson rule), ("reading", Json.mkObj (reading.filter (points.contains ·.1)))] ++ inputs)

/-! ## Reading a request -/

/-- The reading of a request: an object with every point its rule reads and
no other. -/
def readingOf (rule : String) (req : Json) : Except String Json := do
  let points ← pointsOf rule
  let r ← req.getObjVal? "reading"
  let keys := (← r.getObj?).toList.map (·.1)
  if let some k := keys.find? (!points.contains ·) then throw s!"{rule} does not read {k}"
  if let some p := points.find? (!keys.contains ·) then throw s!"{rule} needs the reading point {p}"
  return r

/-- A yes or no point of a reading, or the fallback for a point the rule does
not read. -/
def boolAt (r : Json) (key : String) (fallback : Bool) : Except String Bool :=
  match r.getObjVal? key with
  | .ok v => fromJson? v
  | .error _ => pure fallback

def photoidReadingOf (r : Json) : Except String PhotoidReading := do
  let d : PhotoidReading := default
  return {
    portraitRequired := ← boolAt r "PhotoidReading.portraitRequired" d.portraitRequired,
    unlistedDataAllowed := ← boolAt r "PhotoidReading.unlistedDataAllowed" d.unlistedDataAllowed,
    portraitIsDg2 := ← boolAt r "PhotoidReading.portraitIsDg2" d.portraitIsDg2,
    photoidTableBinds := ← boolAt r "PhotoidReading.photoidTableBinds" d.photoidTableBinds,
    dataGroupsTableBinds := ← boolAt r "PhotoidReading.dataGroupsTableBinds" d.dataGroupsTableBinds,
    repeatedNamesRefused := ← boolAt r "PhotoidReading.repeatedNamesRefused" d.repeatedNamesRefused,
    passportRequired := ← boolAt r "PhotoidReading.passportRequired" d.passportRequired }

def boardingPassReadingOf (r : Json) : Except String BoardingPassReading := do
  return {
    unlistedDataAllowed := ← r.getObjValAs? Bool "BoardingPassReading.unlistedDataAllowed",
    repeatedNamesRefused := ← r.getObjValAs? Bool "BoardingPassReading.repeatedNamesRefused" }

def validityReadingOf (r : Json) : Except String ValidityReading := do
  return {
    departure := ← r.getObjValAs? DepartureReading "ValidityReading.departure",
    soonAfter := ← r.getObjValAs? Nat "ValidityReading.soonAfter" }

/-- The format a request names. -/
def formatOf (req : Json) : Except String Resolution792 := do
  let f ← req.getObjValAs? String "resolution792"
  match formats.lookup f with
  | some x => pure x
  | none => throw s!"unknown Resolution 792 format {f}; the only one is exampleResolution792, an invented stand-in"

/-- The model's answer to one request. -/
def respond (req : Json) : Except String Json := do
  let rule ← req.getObjValAs? String "rule"
  let r ← readingOf rule req
  match rule with
  | "Photoid.violations" =>
    let reading ← photoidReadingOf r
    let tables ← req.getObjValAs? PhotoidTables "tables"
    let m ← req.getObjValAs? Mdoc "credential"
    return findingsResult (Photoid.violations reading tables m)
  | "Photoid.advisories" =>
    let tables ← req.getObjValAs? PhotoidTables "tables"
    let source ← req.getObjValAs? SourceDocument "source"
    let m ← req.getObjValAs? Mdoc "credential"
    return advisoriesResult (Photoid.advisories tables source m)
  | "Photoid.sourceFindings" =>
    let reading ← photoidReadingOf r
    let source ← req.getObjValAs? SourceDocument "source"
    return findingsResult (Photoid.sourceFindings reading source)
  | "Photoid.validityFindings" =>
    let reading ← r.getObjValAs? PhotoidValidityReading "PhotoidValidityReading"
    let documentExpiry ← req.getObjValAs? Instant "documentExpiry"
    let m ← req.getObjValAs? Mdoc "credential"
    return findingsResult (Photoid.validityFindings reading documentExpiry m)
  | "BoardingPass.violations" =>
    let reading ← boardingPassReadingOf r
    let x ← formatOf req
    let m ← req.getObjValAs? Mdoc "credential"
    return findingsResult (BoardingPass.violations reading x m)
  | "BoardingPass.validityFindings" =>
    let reading ← validityReadingOf r
    let j ← req.getObjValAs? Journey "journey"
    let m ← req.getObjValAs? Mdoc "credential"
    return findingsResult (BoardingPass.validityFindings reading j m)
  | "expired" =>
    let validAtEnd ← r.getObjValAs? Bool "ExpiryReading.validAtEnd"
    let m ← req.getObjValAs? Mdoc "credential"
    let now ← req.getObjValAs? Instant "now"
    return boolResult (expired ⟨validAtEnd⟩ m now)
  | "travelerMatch" =>
    let reading ← r.getObjValAs? MatchReading "MatchReading"
    let x ← formatOf req
    let photoid ← req.getObjValAs? Mdoc "photoid"
    let boardingPass ← req.getObjValAs? Mdoc "boardingPass"
    return boolResult (travelerMatch reading x photoid boardingPass)
  | other => throw s!"unknown rule {other}"

/-- One response line for one request line. -/
def handle (line : String) : String :=
  match Json.parse line >>= respond with
  | .ok j => j.compress
  | .error e => (Json.mkObj [("failure", toJson e)]).compress

/-! ## Requests

One builder for each rule, with the reading as a Lean value.  The facts
executable builds the conformance vectors with them. -/

def photoidViolationsRequest (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc) : Json :=
  request "Photoid.violations" (photoidPoints r) [("tables", toJson t), ("credential", toJson m)]

def photoidAdvisoriesRequest (t : PhotoidTables) (source : SourceDocument) (m : Mdoc) : Json :=
  request "Photoid.advisories" [] [("tables", toJson t), ("source", toJson source), ("credential", toJson m)]

def photoidSourceRequest (r : PhotoidReading) (source : SourceDocument) : Json :=
  request "Photoid.sourceFindings" (photoidPoints r) [("source", toJson source)]

def photoidValidityRequest (r : PhotoidValidityReading) (documentExpiry : Instant) (m : Mdoc) : Json :=
  request "Photoid.validityFindings" (photoidValidityPoints r)
    [("documentExpiry", toJson documentExpiry), ("credential", toJson m)]

def boardingPassViolationsRequest (r : BoardingPassReading) (format : String) (m : Mdoc) : Json :=
  request "BoardingPass.violations" (boardingPassPoints r) [("resolution792", toJson format), ("credential", toJson m)]

def boardingPassValidityRequest (v : ValidityReading) (j : Journey) (m : Mdoc) : Json :=
  request "BoardingPass.validityFindings" (validityPoints v) [("journey", toJson j), ("credential", toJson m)]

def expiredRequest (e : ExpiryReading) (m : Mdoc) (now : Instant) : Json :=
  request "expired" (expiryPoints e) [("credential", toJson m), ("now", toJson now)]

def travelerMatchRequest (r : MatchReading) (format : String) (photoid boardingPass : Mdoc) : Json :=
  request "travelerMatch" (matchPoints r)
    [("resolution792", toJson format), ("photoid", toJson photoid), ("boardingPass", toJson boardingPass)]

end Oracle
