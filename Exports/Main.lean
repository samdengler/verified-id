import Lean
import Rules.Core.Attributes

set_option doc.verso false

/-!
# `lake exe oneid-facts`

Loads `Exports.Decisions` from its compiled `.olean` files and runs it in
Lean's interpreter, the same way `lake exe oracle` runs the rules.  Importing
the rules directly would make the executable link Mathlib's native code.

    lake exe oneid-facts

Writes the data a product site reads to `build/one-id-data/`:

* `scenarios.json`: the trips of `Exports/Scenarios.lean`.
* `readings.json`: every undecided point the credential checks take as a
  parameter, labelled from the docstrings of its Lean names, with its
  settings, the checks that read it, and the open criteria and questions it
  bears on.
* `decisions.jsonl`: every scenario under every setting of the points each
  check reads, as an oracle request with the model's response, and the
  boundary vectors for `expired`.

It also writes `build/one-id-identifiers.json`, the document types,
namespaces and data element identifiers with their values from the build,
which `scripts/export_one_id.py` puts in `model.json`.

It writes nothing and exits nonzero, naming the case, if:

* the default scenario gives two results for one check under two reading
  settings, a scenario disagrees with the example it reproduces, or the oracle
  answers a request differently from the model's functions
  (`Exports.decisionLines`);
* a scenario names an example that is not a `@[case]`;
* the reading points a rule's definition reads differ from the ones
  `Oracle.rules` lists, or a field of a reading structure is not a point;
* the settings of a point are not the constructors of its type;
* a point's open theorem is missing, proven, or not tagged
  `@[open_question]`, its docstring does not end with a question, or its
  `_of_` theorem does not mention the point; or an open theorem of a credential
  rule bears on no point;
* the code of a finding or an advisory in the oracle's JSON is not the name of
  its constructor, or its fields are not the constructor's arguments.
-/

open Lean Meta

namespace OneIdFacts

/-- A docstring as the environment stores it, which is Markdown rendered from
Verso, as plain text: the backslash before escaped punctuation dropped, names
left in backticks, and line breaks and runs of spaces folded. -/
def plain (s : String) : String :=
  let rec unescape : List Char → List Char
    | '\\' :: c :: rest => if c.toNat < 128 && !c.isAlphanum && !c.isWhitespace then c :: unescape rest
        else '\\' :: unescape (c :: rest)
    | c :: rest => c :: unescape rest
    | [] => []
  let s := String.ofList (unescape s.toList)
  " ".intercalate (((s.replace "\n" " ").splitOn " ").filter (!·.isEmpty))

/-- The first sentence of a text. -/
def firstSentence (t : String) : String :=
  match t.splitOn ". " with
  | first :: _ :: _ => first ++ "."
  | _ => t

/-- The last sentence of a text. -/
def lastSentence (t : String) : String := ((t.splitOn ". ").getLast?).getD t

/-- The names a docstring quotes in backticks. -/
def quotedNames (doc : String) : List String :=
  ((doc.splitOn "`").zipIdx.filter (·.2 % 2 == 1)).map (·.1)

/-- A duration in seconds as words. -/
def duration (n : Nat) : String :=
  let unit (k : Nat) (one : String) := if k == 1 then s!"1 {one}" else s!"{k} {one}s"
  if n == 0 then "0 seconds"
  else if n % 86400 == 0 then unit (n / 86400) "day"
  else if n % 3600 == 0 then unit (n / 3600) "hour"
  else if n % 60 == 0 then unit (n / 60) "minute"
  else unit n "second"

/-- Every constant a declaration's type and value mention, following the
definitions under `Rules` they use. -/
def closure (env : Environment) (start : Name) : NameSet := Id.run do
  let mut seen : NameSet := NameSet.empty.insert start
  let mut todo : Array Name := #[start]
  let mut i := 0
  while i < todo.size do
    let n := todo[i]!
    i := i + 1
    let some ci := env.find? n | continue
    let used := ci.type.getUsedConstants ++ ((ci.value?.map (·.getUsedConstants)).getD #[])
    for c in used do
      unless seen.contains c do
        seen := seen.insert c
        if (`Rules).isPrefixOf c && (env.find? c matches some (.defnInfo _)) then
          todo := todo.push c
  return seen

/-- The docstring of a declaration, in plain text, or an error. -/
def docOf (n : Name) : CoreM (Except String String) := do
  match ← findDocString? (← getEnv) n with
  | some d => return .ok (plain d)
  | none => return .error s!"{n} has no docstring"

def jsonList (xs : List String) : Json := Json.arr (xs.map toJson).toArray

/-- The label of a yes or no, or a duration, setting.  A constructor setting
is labelled by its docstring instead. -/
def plainLabel : Json → Option String
  | .bool true => some "Yes"
  | .bool false => some "No"
  | .num n => if n.exponent == 0 && n.mantissa ≥ 0 then some (duration n.mantissa.toNat) else none
  | _ => none

/-- The open theorems of the model that check a credential criterion
(OID-101 to OID-199). -/
def credentialQuestions (env : Environment) : List Name :=
  env.constants.toList.filterMap fun (n, ci) =>
    if (`Rules.OneId).isPrefixOf n && ci matches .thmInfo _ && Rules.Core.openQuestionAttr.hasTag env n &&
      (((Rules.Core.checksAttr.getParam? env n).getD "").splitOn " ").any (·.startsWith "OID-1")
    then some n else none

/-- One question a point bears on, or what is wrong with its theorem. -/
def questionEntry (p : String) (marks : List Name) (t : Name) (theorems : List Name) :
    CoreM (Except String Json) := do
  let env ← getEnv
  let some (.thmInfo _) := env.find? t | return .error s!"{p}: {t} is not a theorem"
  unless Rules.Core.openQuestionAttr.hasTag env t do return .error s!"{p}: {t} is not tagged @[open_question]"
  unless (← collectAxioms t).contains ``sorryAx do return .error s!"{p}: {t} is proven, so it is no longer open"
  let some raw ← findDocString? env t | return .error s!"{p}: {t} has no docstring"
  let doc := plain raw
  let question := lastSentence doc
  unless question.endsWith "?" do return .error s!"{p}: the docstring of {t} does not end with its question"
  -- A proven version for one reading is named after the open theorem; it must
  -- state that reading through the point.
  let partners := theorems.filter fun n => (n.toString.splitOn (t.toString ++ "_of_")).length > 1
  if !partners.isEmpty && !partners.any (fun q =>
      ((env.find? q).map fun ci => marks.any ci.type.getUsedConstants.contains).getD false) then
    return .error s!"{p}: no theorem {t}_of_... mentions the point"
  let criteria := ((Rules.Core.checksAttr.getParam? env t).getD "").splitOn " " |>.filter (!·.isEmpty)
  let examples := (quotedNames raw).filterMap fun s =>
    let n := `Rules.OneId ++ s.toName
    if Rules.Core.caseAttr.hasTag env n then some n.toString else none
  return .ok (Json.mkObj [("theorem", toJson t.toString), ("criteria", jsonList criteria),
    ("question", toJson question), ("examples", jsonList examples)])

/-- The entry of one point in `readings.json`, or what is wrong with it. -/
def pointEntry (rules : List (String × Name × List String)) (theorems : List Name)
    (point : String × Name × Option Name × List Json × List Name) : CoreM (Except String Json) := do
  let (id, lean, settingsType, settings, questions) := point
  let env ← getEnv
  let doc ← match ← docOf lean with | .ok d => pure d | .error e => return .error e
  let mut description := doc
  let mut settingEntries := #[]
  let mut asWritten := Json.null
  let mut marks := [lean]
  match settingsType with
  | some ty =>
    let some (.inductInfo info) := env.find? ty | return .error s!"{id}: {ty} is not an inductive type"
    let names := info.ctors.map (·.getString!)
    unless settings.map (·.getStr?.toOption.getD "") == names do
      return .error s!"{id}: its settings {settings.map (·.compress)} are not the constructors of {ty}, {names}"
    if ty != lean then
      match ← docOf ty with
      | .ok d => description := description ++ " " ++ d
      | .error e => return .error e
    marks := marks ++ ty :: info.ctors
    for c in info.ctors do
      let cdoc ← match ← docOf c with | .ok d => pure d | .error e => return .error e
      let value := toJson c.getString!
      if (cdoc.toLower.splitOn "the guide as written").length > 1 then asWritten := value
      settingEntries := settingEntries.push (Json.mkObj [("value", value), ("label", toJson (firstSentence cdoc)),
        ("description", toJson cdoc), ("lean", toJson c.toString)])
  | none =>
    for s in settings do
      let some label := plainLabel s | return .error s!"{id}: no label for the setting {s.compress}"
      settingEntries := settingEntries.push (Json.mkObj [("value", s), ("label", toJson label)])
  let mut entries := #[]
  for t in questions do
    match ← questionEntry id marks t theorems with
    | .ok e => entries := entries.push e
    | .error e => return .error e
  let criteria := (entries.toList.flatMap fun e =>
    ((e.getObjVal? "criteria").toOption.bind (fromJson? (α := List String) · |>.toOption)).getD []).eraseDups
  let checks := rules.filterMap fun (r, _, ps) => if ps.contains id then some r else none
  return .ok (Json.mkObj [("id", toJson id), ("lean", toJson lean.toString),
    ("label", toJson (firstSentence doc)), ("description", toJson description),
    ("settings", Json.arr settingEntries), ("asWritten", asWritten), ("checks", jsonList checks),
    ("criteria", jsonList criteria), ("questions", Json.arr entries)])

/-- Nothing, or where the oracle's JSON for a finding or an advisory differs
from its constructor: the code must be the constructor's name and the fields
its arguments. -/
def codecErrors (ty encoder : Name) : MetaM (List String) := do
  let mut errors := []
  for ctor in (← getConstInfoInduct ty).ctors do
    let info ← getConstInfoCtor ctor
    let err ← forallTelescopeReducing info.type fun xs _ => do
      let mut args := #[]
      for x in xs do
        unless (← inferType x).isConstOf ``String do return some s!"{ctor} has an argument that is not a string"
        args := args.push (mkStrLit (← x.fvarId!.getUserName).toString)
      let names := (← xs.mapM fun x => x.fvarId!.getUserName).toList.map (·.toString)
      let j ← unsafe evalExpr Json (mkConst ``Json) (mkApp (mkConst encoder) (mkAppN (mkConst ctor) args))
      let keys := ((j.getObj?.toOption.map (·.toList.map (·.1))).getD []).filter (· != "code")
      if (j.getObjValAs? String "code").toOption != some ctor.getString! then
        return some s!"{encoder} gives {ctor} the code {(j.getObjValD "code").compress}"
      unless keys.all names.contains && names.all keys.contains do
        return some s!"{encoder} gives {ctor} the fields {keys}, and its arguments are {names}"
      -- Each argument was given its own name as its value.
      for n in names do
        if j.getObjValD n != toJson n then
          return some s!"{encoder} puts the wrong argument of {ctor} under {n}"
      return none
    if let some e := err then errors := errors ++ [e]
  return errors

/-- The identifier constants with their values from the build. -/
def identifiersJson (env : Environment) (table : List (String × List (Name × Option Name))) :
    CoreM (Except String Json) := do
  let value (n : Name) : Except String String := unsafe env.evalConst String {} n
  let mut kinds := #[]
  for (kind, names) in table do
    let mut entries := #[]
    for (n, ns) in names do
      let v ← match value n with | .ok v => pure v | .error e => return .error s!"{n}: {e}"
      let doc ← match ← docOf n with | .ok d => pure d | .error e => return .error e
      let mut fields := [("name", toJson n.getString!), ("lean", toJson n.toString), ("value", toJson v),
        ("description", toJson doc)]
      if let some ns := ns then
        let nv ← match value ns with | .ok v => pure v | .error e => return .error s!"{ns}: {e}"
        fields := fields ++ [("nameSpace", toJson nv)]
      entries := entries.push (Json.mkObj fields)
    kinds := kinds.push (kind, Json.arr entries)
  return .ok (Json.mkObj kinds.toList)

/-- Every check that needs the environment: the rules against their
definitions, the readings, the examples and the oracle's JSON.  The readings
and the identifiers as JSON, or every error. -/
def checkAndDescribe : MetaM (Except (List String) (Json × Json)) := do
  let env ← getEnv
  let eval {α} (n : Name) : Except String α := unsafe env.evalConst α {} n
  let get {α} (n : Name) : MetaM (Except String α) := pure (eval n)
  let .ok rules ← get (α := List (String × Name × List String)) `Oracle.rules | return .error ["cannot read Oracle.rules"]
  let .ok pointTable ← get (α := List (String × Name × Option Name × List Json × List Name)) `Exports.pointTable
    | return .error ["cannot read Exports.pointTable"]
  let .ok structures ← get (α := List Name) `Exports.readingStructures | return .error ["cannot read Exports.readingStructures"]
  let .ok examples ← get (α := List (String × Name)) `Exports.scenarioExamples
    | return .error ["cannot read Exports.scenarioExamples"]
  let .ok identifiers ← get (α := List (String × List (Name × Option Name))) `Exports.identifierTable
    | return .error ["cannot read Exports.identifierTable"]
  let mut errors : List String := []
  -- The reading points each rule's definition reads, against Oracle.rules.
  for (rule, fn, listed) in rules do
    let used := closure env fn
    let reads := pointTable.filterMap fun (id, lean, _) => if used.contains lean then some id else none
    unless reads.all listed.contains && listed.all reads.contains do
      errors := errors ++ [s!"{rule}: its definition reads {reads}, and Oracle.rules lists {listed}"]
  -- Every field of a reading structure is a point.
  for s in structures do
    for f in getStructureFields env s do
      unless pointTable.any (·.2.1 == s ++ f) do
        errors := errors ++ [s!"the field {s ++ f} is not a reading point in Exports.points"]
  -- The examples the scenarios reproduce.
  for (id, n) in examples do
    unless Rules.Core.caseAttr.hasTag env n do
      errors := errors ++ [s!"scenario {id} reproduces {n}, which is not a @[case] example"]
  -- The oracle's JSON for findings and advisories.
  errors := errors ++ (← codecErrors `Rules.OneId.Finding `Oracle.findingJson) ++
    (← codecErrors `Rules.OneId.Advisory `Oracle.advisoryJson)
  -- The readings.
  let theorems := env.constants.toList.filterMap fun (n, ci) =>
    if (`Rules.OneId).isPrefixOf n && ci matches .thmInfo _ then some n else none
  let mut readings := #[]
  for p in pointTable do
    match ← pointEntry rules theorems p with
    | .ok e => readings := readings.push e
    | .error e => errors := errors ++ [e]
  let linked := pointTable.flatMap (·.2.2.2.2)
  for q in credentialQuestions env do
    unless linked.contains q do
      errors := errors ++ [s!"the open theorem {q} bears on no reading point in Exports.points"]
  let ids ← match ← identifiersJson env identifiers with
    | .ok j => pure j
    | .error e => errors := errors ++ [e]; pure Json.null
  if !errors.isEmpty then return .error errors
  return .ok (Json.mkObj [("generatedBy", toJson "lake exe oneid-facts"), ("readings", Json.arr readings)],
    Json.mkObj [("generatedBy", toJson "lake exe oneid-facts"), ("identifiers", ids)])

end OneIdFacts

open OneIdFacts in
def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Exports.Decisions }] {} (loadExts := true)
  let fail (errors : List String) : IO UInt32 := do
    for e in errors do IO.eprintln s!"oneid-facts: {e}"
    return 1
  let lines ← IO.ofExcept <| unsafe env.evalConst (Except String (List String)) {} `Exports.decisionLines
  let lines ← match lines with
    | .ok ls => pure ls
    | .error e => return ← fail [e]
  let scenarios ← IO.ofExcept <| unsafe env.evalConst Json {} `Exports.scenariosJson
  let ctx : Core.Context := { fileName := "<oneid-facts>", fileMap := default }
  let ((described, _), _) ← (checkAndDescribe.run {} {}).toIO ctx { env }
  let (readings, identifiers) ← match described with
    | .ok r => pure r
    | .error es => return ← fail es
  IO.FS.createDirAll "build/one-id-data"
  IO.FS.writeFile "build/one-id-data/scenarios.json" (scenarios.pretty ++ "\n")
  IO.FS.writeFile "build/one-id-data/readings.json" (readings.pretty ++ "\n")
  IO.FS.writeFile "build/one-id-data/decisions.jsonl" ("\n".intercalate lines ++ "\n")
  IO.FS.writeFile "build/one-id-identifiers.json" (identifiers.pretty ++ "\n")
  let nScenarios := ((scenarios.getObjVal? "scenarios" >>= Json.getArr?).toOption.map (·.size)).getD 0
  let nReadings := ((readings.getObjVal? "readings" >>= Json.getArr?).toOption.map (·.size)).getD 0
  IO.println s!"wrote build/one-id-data/: {nScenarios} scenarios, {nReadings} reading points, {lines.length} decisions"
  return 0
