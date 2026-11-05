import Oracle.Handle

set_option doc.verso false

/-!
# Scenarios

Trips a product site can show, each with the credentials a traveler holds, who
each one is about, the journey and the instant of the check.  They are built
with the builders of `Rules/OneId/Examples.lean`, and every one but the
default reproduces a `@[case]` example: `exampleAgrees` recomputes that
example's record from the scenario's own inputs, and `lake exe oneid-facts`
stops if it differs from what the example computes.

The default trip is built so that every check gives the same result under
every reading.  `lake exe oneid-facts` stops if it does not.

The tables and the boarding pass format the checks use are the invented
stand-ins of `Rules/OneId/Examples.lean`, so every scenario carries a flag
saying so.
-/

open Lean Rules.Core Rules.OneId Oracle

namespace Exports

/-- The document a photoid was derived from, as its issuer knows it. -/
structure DerivedFrom where
  /-- The kind of document. -/
  kind : SourceDocument
  /-- When it expires. -/
  expires : Instant
  deriving Repr

/-- One trip a product site can show. -/
structure Scenario where
  /-- A stable identifier. -/
  id : String
  /-- One line that says what happens. -/
  title : String
  /-- Whether this is the trip a site shows first. -/
  isDefault : Bool := false
  /-- The photoid, with the traveler it is about. -/
  photoid : Option Issued := none
  /-- The boarding pass, with the traveler it is about. -/
  boardingPass : Option Issued := none
  /-- The journey of the boarding pass. -/
  journey : Option Journey := none
  /-- The instant of the check. -/
  checkedAt : Instant
  /-- The document the photoid was derived from. -/
  derivedFrom : Option DerivedFrom := none
  /-- The `@[case]` example the scenario reproduces. -/
  reproduces : Option Name := none

/-! ## Times -/

/-- 08:30 UTC on 1 March 2027, an hour and a half before the departure of the
examples. -/
def beforeBoarding : Instant := ⟨1803889800⟩

/-- A journey that departs on time at 10:00 UTC on 1 March 2027 and is
completed at 12:00. -/
def onTime : Journey := ⟨departure, departure, ⟨1803902400⟩⟩

/-- A passport that expires on 1 January 2031, a year after the validity of
the photoids of the examples ends. -/
def passport : DerivedFrom := ⟨.passport, ⟨1924992000⟩⟩

/-! ## The scenarios -/

def defaultTrip : Scenario :=
  { id := "default-trip", isDefault := true,
    title := "Alice Martin checks in with her photoid and her own boarding pass before a 10:00 UTC departure",
    photoid := some ⟨photoidOf "MARTIN" "ALICE", ⟨"traveler 1"⟩⟩,
    boardingPass := some ⟨boardingPassOf "MARTIN/ALICE", ⟨"traveler 1"⟩⟩,
    journey := some onTime, checkedAt := beforeBoarding, derivedFrom := some passport }

def accentedName : Scenario :=
  { id := "accented-name",
    title := "José María García's passport name has accents and his boarding pass name does not",
    photoid := some ⟨photoidOf "GARCÍA" "JOSÉ MARÍA", ⟨"traveler 1"⟩⟩,
    boardingPass := some ⟨boardingPassOf "GARCIA/JOSEMARIA", ⟨"traveler 1"⟩⟩,
    journey := some onTime, checkedAt := beforeBoarding, derivedFrom := some passport,
    reproduces := some ``ownBoardingPassRefused }

def twoJohnSmiths : Scenario :=
  { id := "two-john-smiths",
    title := "One John Smith's photoid is presented with another John Smith's boarding pass",
    photoid := some ⟨photoidOf "SMITH" "JOHN", ⟨"traveler 1"⟩⟩,
    boardingPass := some ⟨boardingPassOf "SMITH/JOHN", ⟨"traveler 2"⟩⟩,
    journey := some onTime, checkedAt := beforeBoarding, derivedFrom := some passport,
    reproduces := some ``twoTravelersWithOneName }

def anotherTravelersPass : Scenario :=
  { id := "another-travelers-pass",
    title := "Alice Martin's photoid is presented with Bruno Keller's boarding pass",
    photoid := some ⟨photoidOf "MARTIN" "ALICE", ⟨"traveler 1"⟩⟩,
    boardingPass := some ⟨boardingPassOf "KELLER/BRUNO", ⟨"traveler 2"⟩⟩,
    journey := some onTime, checkedAt := beforeBoarding, derivedFrom := some passport,
    reproduces := some ``anotherTravelersBoardingPass }

def delayedFlight : Scenario :=
  { id := "delayed-flight",
    title := "The flight leaves three hours late and the boarding pass ends an hour after the scheduled departure",
    boardingPass := some ⟨{ boardingPassOf "SMITH/JOHN" with validUntil := ⟨1803898800⟩ }, ⟨"traveler 1"⟩⟩,
    journey := some ⟨departure, ⟨1803906000⟩, ⟨1803913200⟩⟩, checkedAt := ⟨1803904200⟩,
    reproduces := some ``expiredBeforeADelayedDeparture }

def endOfValidity : Scenario :=
  { id := "end-of-validity",
    title := "The boarding pass is read at the exact instant its validity ends, the scheduled departure",
    boardingPass := some ⟨boardingPassOf "SMITH/JOHN", ⟨"traveler 1"⟩⟩,
    journey := some onTime, checkedAt := departure,
    reproduces := some ``atTheEndOfValidity }

def validAfterJourney : Scenario :=
  { id := "valid-after-journey",
    title := "The boarding pass is still valid two hours after the flight has landed",
    boardingPass := some ⟨{ boardingPassOf "SMITH/JOHN" with validUntil := ⟨1803981600⟩ }, ⟨"traveler 1"⟩⟩,
    journey := some onTime, checkedAt := ⟨1803909600⟩,
    reproduces := some ``validAfterTheJourney }

/-- A base identity namespace with a family name and a given name and no
portrait. -/
def namesOnly : NameSpace :=
  { name := baseNameSpace, elements := [⟨familyNameId, .text "SMITH"⟩, ⟨givenNameId, .text "JOHN"⟩] }

def noPortrait : Scenario :=
  { id := "no-portrait",
    title := "The photoid has a family name and a given name and no face image",
    photoid := some ⟨{ photoidOf "SMITH" "JOHN" with nameSpaces := [namesOnly] }, ⟨"traveler 1"⟩⟩,
    checkedAt := beforeBoarding, derivedFrom := some passport,
    reproduces := some ``photoidWithoutPortrait }

def identityCard : Scenario :=
  { id := "identity-card",
    title := "The photoid was derived from a national identity card",
    photoid := some ⟨photoidOf "SMITH" "JOHN", ⟨"traveler 1"⟩⟩,
    checkedAt := beforeBoarding, derivedFrom := some ⟨.other, passport.expires⟩,
    reproduces := some ``photoidFromAnIdentityCard }

def outlivesPassport : Scenario :=
  { id := "outlives-passport",
    title := "The photoid is checked two weeks after the passport it came from has expired",
    photoid := some ⟨photoidOf "SMITH" "JOHN", ⟨"traveler 1"⟩⟩,
    checkedAt := ⟨1815642000⟩, derivedFrom := some ⟨.passport, ⟨1814313600⟩⟩,
    reproduces := some ``photoidOutlivesItsPassport }

/-- A namespace the guide does not list, with the seat in it. -/
def seatNameSpace : NameSpace :=
  { name := "org.example.boardingpass.fields.1", elements := [⟨"seat", .text "12A"⟩] }

def extraNameSpace : Scenario :=
  { id := "extra-namespace",
    title := "The boarding pass carries the seat in a second namespace the guide does not list",
    boardingPass := some ⟨{ boardingPassOf "SMITH/JOHN" with
      nameSpaces := (boardingPassOf "SMITH/JOHN").nameSpaces ++ [seatNameSpace] }, ⟨"traveler 1"⟩⟩,
    journey := some onTime, checkedAt := beforeBoarding,
    reproduces := some ``boardingPassWithExtraNameSpace }

/-- A boarding pass namespace with two boarding pass strings. -/
def twoPassengers : NameSpace :=
  { name := bcbpNameSpace,
    elements := [⟨bcbpStringId, .text "EXAMPLE:SMITH/JOHN"⟩, ⟨bcbpStringId, .text "EXAMPLE:JONES/MARY"⟩] }

def twoStrings : Scenario :=
  { id := "two-strings",
    title := "The boarding pass holds two boarding pass strings, for John Smith and for Mary Jones",
    boardingPass := some ⟨{ boardingPassOf "SMITH/JOHN" with nameSpaces := [twoPassengers] }, ⟨"traveler 1"⟩⟩,
    journey := some onTime, checkedAt := beforeBoarding,
    reproduces := some ``twoBoardingPassStrings }

/-- Every scenario, the default first. -/
def scenarios : List Scenario :=
  [defaultTrip, accentedName, twoJohnSmiths, anotherTravelersPass, delayedFlight, endOfValidity,
   validAfterJourney, noPortrait, identityCard, outlivesPassport, extraNameSpace, twoStrings]

/-! ## Agreement with the examples -/

/-- The record of the example a scenario reproduces, recomputed from the
scenario's own inputs under the readings the example uses, compared with the
value the example computes.  `none` when the scenario lacks an input the
example needs. -/
def exampleChecks : List (Name × (Scenario → Option Bool)) :=
  let pair (r : MatchReading) (expected : PairCheck) (s : Scenario) : Option Bool := do
    return checkPair r (← s.photoid) (← s.boardingPass) == expected
  let validity (v : ValidityReading) (expected : ValidityCheck) (s : Scenario) : Option Bool := do
    let b := (← s.boardingPass).mdoc
    let j ← s.journey
    return expected ==
      { scheduledDeparture := j.scheduledDeparture, actualDeparture := j.actualDeparture,
        journeyCompleted := j.completed, validityEnds := b.validUntil,
        requirementsBroken := BoardingPass.validityFindings v j b, checkedAt := s.checkedAt,
        expired := expired ⟨true⟩ b s.checkedAt }
  [(``ownBoardingPassRefused, pair .namesAgree ownBoardingPassRefused),
   (``twoTravelersWithOneName, pair .namesAgree twoTravelersWithOneName),
   (``anotherTravelersBoardingPass, pair .notChecked anotherTravelersBoardingPass),
   (``expiredBeforeADelayedDeparture, validity ⟨.scheduled, 3600⟩ expiredBeforeADelayedDeparture),
   (``validAfterTheJourney, validity ⟨.scheduled, 86400⟩ validAfterTheJourney),
   (``atTheEndOfValidity, fun s => do
     let b := (← s.boardingPass).mdoc
     return atTheEndOfValidity ==
       { validityEnds := b.validUntil, checkedAt := s.checkedAt,
         expiredIfStillValidAtTheEnd := expired ⟨true⟩ b s.checkedAt,
         expiredIfNoLongerValidAtTheEnd := expired ⟨false⟩ b s.checkedAt }),
   (``photoidWithoutPortrait, fun s => do
     let p := (← s.photoid).mdoc
     return photoidWithoutPortrait ==
       { strictReading := Photoid.violations strictPhotoid exampleTables p,
         looseReading := Photoid.violations loosePhotoid exampleTables p }),
   (``photoidFromAnIdentityCard, fun s => do
     let p := (← s.photoid).mdoc
     let d ← s.derivedFrom
     return photoidFromAnIdentityCard ==
       { brokenIfAPassportIsRequired := Photoid.sourceFindings strictPhotoid d.kind,
         brokenIfAnEquivalentDocumentIsAllowed := Photoid.sourceFindings loosePhotoid d.kind,
         recommendationsNotFollowed := Photoid.advisories exampleTables d.kind p }),
   (``photoidOutlivesItsPassport, fun s => do
     let p := (← s.photoid).mdoc
     let d ← s.derivedFrom
     return photoidOutlivesItsPassport ==
       { passportExpires := d.expires, validityEnds := p.validUntil,
         brokenIfAnyEndIsAllowed := Photoid.validityFindings .unbounded d.expires p,
         brokenIfItMustEndWithThePassport := Photoid.validityFindings .endsWithDocument d.expires p,
         checkedAt := s.checkedAt, expired := expired ⟨true⟩ p s.checkedAt }),
   (``boardingPassWithExtraNameSpace, fun s => do
     let b := (← s.boardingPass).mdoc
     return boardingPassWithExtraNameSpace ==
       { strictReading := BoardingPass.violations strictBoardingPass exampleResolution792 b,
         looseReading := BoardingPass.violations looseBoardingPass exampleResolution792 b }),
   (``twoBoardingPassStrings, fun s => do
     let b := (← s.boardingPass).mdoc
     return twoBoardingPassStrings ==
       { namesAreUnique := b.wellFormed, valueReturned := b.element? bcbpNameSpace bcbpStringId,
         brokenIfRepeatedNamesAreRefused :=
           BoardingPass.violations { looseBoardingPass with repeatedNamesRefused := true } exampleResolution792 b,
         brokenIfRepeatedNamesAreAllowed := BoardingPass.violations looseBoardingPass exampleResolution792 b })]

/-- Nothing, or the reason a scenario disagrees with the example it
reproduces. -/
def exampleAgrees (s : Scenario) : Except String Unit :=
  match s.reproduces with
  | none => pure ()
  | some n =>
    match exampleChecks.lookup n with
    | none => throw s!"scenario {s.id} reproduces {n}, which has no check in Exports.exampleChecks"
    | some check =>
      match check s with
      | some true => pure ()
      | some false => throw s!"scenario {s.id} disagrees with the example {n}: its inputs give a different record"
      | none => throw s!"scenario {s.id} lacks an input the example {n} needs"

/-! ## As JSON -/

/-- The stand-ins every check of a scenario uses. -/
def standInsJson : Json :=
  Json.mkObj [
    ("invented", toJson true),
    ("tables", Json.mkObj [("lean", toJson (``exampleTables).toString), ("value", toJson exampleTables)]),
    ("resolution792", Json.mkObj [("lean", toJson (``exampleResolution792).toString),
      ("format", toJson "exampleResolution792")])]

def issuedJson (role : String) (c : Issued) : Json :=
  Json.mkObj [("role", toJson role), ("about", toJson c.subject.id), ("mdoc", toJson c.mdoc)]

def Scenario.json (s : Scenario) : Json :=
  Json.mkObj [
    ("id", toJson s.id), ("title", toJson s.title), ("default", toJson s.isDefault),
    ("credentials", Json.arr ((s.photoid.toList.map (issuedJson "photoid")) ++
      (s.boardingPass.toList.map (issuedJson "boardingPass"))).toArray),
    ("journey", match s.journey with | some j => toJson j | none => Json.null),
    ("checkedAt", toJson s.checkedAt),
    ("sourceDocument", match s.derivedFrom with
      | some d => Json.mkObj [("kind", toJson d.kind), ("expires", toJson d.expires)]
      | none => Json.null),
    ("standIns", toJson true),
    ("example", match s.reproduces with | some n => toJson n.toString | none => Json.null)]

end Exports
