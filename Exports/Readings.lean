import Oracle.Handle

set_option doc.verso false

/-!
# Readings as data

Every point the credential checks take as a parameter, with its settings.  A
point is a field of a reading structure, or a reading type whose constructors
are its settings.  Its id is its Lean name below `Rules.OneId`, the same key
the oracle reads it under.

Only the settings and the open theorems each point bears on are written here.
`lake exe oneid-facts` takes the labels from the docstrings of the Lean names,
the checks that take a point from `Oracle.rules` after checking that list
against the definitions of the rules, and the criteria and the question from
each open theorem.
-/

open Lean Rules.Core Rules.OneId

namespace Exports

/-! ## Settings

Every setting of each reading type.  A product site can show the result of a
check for any combination of them. -/

def bools : List Bool := [true, false]

def photoidReadings : List PhotoidReading :=
  bools.flatMap fun a => bools.flatMap fun b => bools.flatMap fun c => bools.flatMap fun d =>
  bools.flatMap fun e => bools.flatMap fun f => bools.map fun g => ⟨a, b, c, d, e, f, g⟩

def boardingPassReadings : List BoardingPassReading :=
  bools.flatMap fun a => bools.map fun b => ⟨a, b⟩

def expiryReadings : List ExpiryReading := bools.map (⟨·⟩)

/-- How long "soon after" may last: none at all, an hour, and a day.  The
guide gives no limit, so these are a sample.  The examples use an hour and a
day. -/
def soonAfterSettings : List Nat := [0, 3600, 86400]

def departureReadings : List DepartureReading := [.scheduled, .actual]

def validityReadings : List ValidityReading :=
  departureReadings.flatMap fun d => soonAfterSettings.map fun s => ⟨d, s⟩

def matchReadings : List MatchReading := [.notChecked, .namesAgree]

def photoidValidityReadings : List PhotoidValidityReading := [.unbounded, .endsWithDocument]

/-- Every point of every setting of every reading type, as the oracle encodes
it. -/
def allPoints : List (List (String × Json)) :=
  photoidReadings.map Oracle.photoidPoints ++ boardingPassReadings.map Oracle.boardingPassPoints ++
    expiryReadings.map Oracle.expiryPoints ++ validityReadings.map Oracle.validityPoints ++
    matchReadings.map Oracle.matchPoints ++ photoidValidityReadings.map Oracle.photoidValidityPoints

/-- The settings of a point, in order. -/
def settingsOf (id : String) : List Json := (allPoints.filterMap (·.lookup id)).eraseDups

/-! ## The points -/

/-- One undecided point a check takes as a parameter. -/
structure Point where
  /-- The Lean name whose docstring labels the point: the field of a reading
  structure, or the reading type. -/
  lean : Name
  /-- For a point whose settings are the constructors of a type, the type;
  their docstrings label the settings. -/
  settingsType : Option Name := none
  /-- The open theorems whose question the point bears on. -/
  questions : List Name

/-- The point's id: its Lean name below `Rules.OneId`. -/
def Point.id (p : Point) : String := (p.lean.replacePrefix `Rules.OneId .anonymous).toString

def points : List Point :=
  [{ lean := ``PhotoidReading.portraitRequired, questions := [``photoid_has_portrait] },
   { lean := ``PhotoidReading.unlistedDataAllowed, questions := [``photoid_only_listed] },
   { lean := ``PhotoidReading.portraitIsDg2, questions := [``portrait_is_dg2] },
   { lean := ``PhotoidReading.photoidTableBinds, questions := [``photoid_nameSpace_complete] },
   { lean := ``PhotoidReading.dataGroupsTableBinds, questions := [``dataGroups_nameSpace_complete] },
   { lean := ``PhotoidReading.repeatedNamesRefused, questions := [``photoid_names_unique] },
   { lean := ``PhotoidReading.passportRequired, questions := [``photoid_from_passport] },
   { lean := ``BoardingPassReading.unlistedDataAllowed, questions := [``boardingPass_only_listed] },
   { lean := ``BoardingPassReading.repeatedNamesRefused, questions := [``boardingPass_names_unique] },
   { lean := ``ExpiryReading.validAtEnd, questions := [``valid_at_validUntil] },
   { lean := ``ValidityReading.departure, settingsType := some ``DepartureReading,
     questions := [``valid_until_actual_departure] },
   { lean := ``ValidityReading.soonAfter, questions := [``expired_once_journey_completed] },
   { lean := ``MatchReading, settingsType := some ``MatchReading,
     questions := [``matched_pair_same_traveler, ``same_traveler_matches] },
   { lean := ``PhotoidValidityReading, settingsType := some ``PhotoidValidityReading,
     questions := [``photoid_expires_with_document] }]

/-- The points as the facts executable reads them: id, Lean name, the type of
the settings, the settings, and the open theorems. -/
def pointTable : List (String × Name × Option Name × List Json × List Name) :=
  points.map fun p => (p.id, p.lean, p.settingsType, settingsOf p.id, p.questions)

/-- The reading structures whose every field must be a point. -/
def readingStructures : List Name :=
  [``PhotoidReading, ``BoardingPassReading, ``ExpiryReading, ``ValidityReading]

end Exports
