import Rules.OneId.Theorems

/-!
# Examples of credentials

Concrete credentials the build checks.  Each {attr}`@[case]` declaration is
shown in the review document with its computed value, and each {lit}`#guard`
fails the build if that value changes.  The names, images, strings and times
are invented.  The tables and the boarding pass format used here are stand-ins
for specifications this project has not read.
-/

namespace Rules.OneId

open Rules.Core

/-! ## Stand-ins and readings -/

/-- A stand-in for Tables C.1 to C.3 of ISO/IEC TS 23220-4, invented for the
examples.  The identifiers of the names, the portrait, the age attestation,
the image captured at enrolment and the data groups are the ones the guide
prints; the presence and encoding of each are made up, and
{lit}`example_document_number` is not a real identifier. -/
def exampleTables : PhotoidTables :=
  { base := ⟨[⟨"family_name", .mandatory, .text⟩, ⟨"given_name", .mandatory, .text⟩,
      ⟨"portrait", .optional, .bytes⟩, ⟨"age_over_18", .optional, .flag⟩]⟩,
    photoid := ⟨[⟨"example_document_number", .mandatory, .text⟩,
      ⟨"enrolment_portrait_image", .optional, .bytes⟩]⟩,
    dataGroups := ⟨[⟨"dg1", .optional, .bytes⟩, ⟨"dg2", .optional, .bytes⟩, ⟨"sod", .mandatory, .bytes⟩]⟩ }

/-- A stand-in for IATA Resolution 792, invented for the examples.  It treats
a string as a boarding pass string when it is the word EXAMPLE, a colon, and a
family name and a given name separated by a slash.  The real format is not
modelled. -/
def exampleResolution792 : Resolution792 :=
  { follows := fun s => match s.splitOn ":" with
      | ["EXAMPLE", _] => true
      | _ => false
    passenger := fun s => match s.splitOn ":" with
      | ["EXAMPLE", name] => match name.splitOn "/" with
        | [family, given] => some (family, given)
        | _ => none
      | _ => none }

/-- The strict reading of the photoid requirements: the portrait and a
passport are required, the lists of namespaces and data elements are closed,
the portrait must be data group 2, a table binds once its namespace is
present, and repeated names are refused. -/
def strictPhotoid : PhotoidReading :=
  { portraitRequired := true, unlistedDataAllowed := false, portraitIsDg2 := true,
    photoidTableBinds := true, dataGroupsTableBinds := true, repeatedNamesRefused := true,
    passportRequired := true }

/-- The loose reading of the photoid requirements: each point the guide leaves
undecided is allowed. -/
def loosePhotoid : PhotoidReading :=
  { portraitRequired := false, unlistedDataAllowed := true, portraitIsDg2 := false,
    photoidTableBinds := false, dataGroupsTableBinds := false, repeatedNamesRefused := false,
    passportRequired := false }

/-- The strict reading of the boarding pass requirements: nothing the guide
does not list is allowed, and repeated names are refused. -/
def strictBoardingPass : BoardingPassReading :=
  { unlistedDataAllowed := false, repeatedNamesRefused := true }

/-- The loose reading of the boarding pass requirements: data the guide does
not list and repeated names are allowed. -/
def looseBoardingPass : BoardingPassReading :=
  { unlistedDataAllowed := true, repeatedNamesRefused := false }

/-- What the model finds under the two readings of a point the guide leaves
undecided. -/
structure ByReading where
  /-- The requirements broken under the strict reading. -/
  strictReading : List Finding
  /-- The requirements broken under the loose reading. -/
  looseReading : List Finding
  deriving DecidableEq, Repr

/-! ## Example credentials -/

/-- 1 March 2027 at 10:00 UTC, the scheduled departure in the examples. -/
def departure : Instant := ⟨1803895200⟩

/-- An invented face image. -/
def faceA : Value := .bytes [1, 2, 3]

/-- A different invented face image. -/
def faceB : Value := .bytes [9, 9, 9]

/-- A base identity namespace with a family name, a given name and a
portrait. -/
def baseOf (familyName givenName : String) (portrait : Value) : NameSpace :=
  { name := baseNameSpace,
    elements := [⟨familyNameId, .text familyName⟩, ⟨givenNameId, .text givenName⟩, ⟨portraitId, portrait⟩] }

/-- A photoid with only the base identity namespace: a family name, a given
name and a portrait.  Its validity ends on 1 January 2030. -/
def photoidOf (familyName givenName : String) : Mdoc :=
  { docType := photoidDocType, nameSpaces := [baseOf familyName givenName faceA],
    validUntil := ⟨1893456000⟩ }

/-- A boarding pass with one boarding pass string in the stand-in format.  Its
validity ends at the scheduled departure. -/
def boardingPassOf (name : String) : Mdoc :=
  { docType := boardingPassDocType,
    nameSpaces := [{ name := bcbpNameSpace, elements := [⟨bcbpStringId, .text ("EXAMPLE:" ++ name)⟩] }],
    validUntil := departure }

/-! ## Data elements and their names -/

/-- What a credential with a repeated identifier gives a request. -/
structure RepeatedName where
  /-- Whether the names in the credential are unique. -/
  namesAreUnique : Bool
  /-- The value a request for the repeated identifier receives. -/
  valueReturned : Option Value
  /-- The requirements broken if repeated names are refused. -/
  brokenIfRepeatedNamesAreRefused : List Finding
  /-- The requirements broken if repeated names are allowed. -/
  brokenIfRepeatedNamesAreAllowed : List Finding
  deriving DecidableEq, Repr

/-- *Given* a photoid whose base identity namespace holds two data elements
with the identifier of the family name, SMITH and then JONES.

*When* a relying party requests the family name, and the photoid is checked
under each reading of repeated names.

*Then* the request is ambiguous and one of the two values is returned.  The
reading that refuses repeated names rejects the photoid; the other accepts
it. -/
@[case, checks "OID-106.3"]
def repeatedIdentifier : RepeatedName :=
  let base : NameSpace := baseOf "SMITH" "JOHN" faceA
  let twice : NameSpace := { base with elements := base.elements ++ [⟨familyNameId, .text "JONES"⟩] }
  let m : Mdoc := { photoidOf "SMITH" "JOHN" with nameSpaces := [twice] }
  { namesAreUnique := m.wellFormed, valueReturned := m.element? baseNameSpace familyNameId,
    brokenIfRepeatedNamesAreRefused :=
      Photoid.violations { loosePhotoid with repeatedNamesRefused := true } exampleTables m,
    brokenIfRepeatedNamesAreAllowed := Photoid.violations loosePhotoid exampleTables m }

#guard repeatedIdentifier ==
  { namesAreUnique := false, valueReturned := some (.text "SMITH"),
    brokenIfRepeatedNamesAreRefused := [.repeatedName], brokenIfRepeatedNamesAreAllowed := [] }

/-! ## The photoid -/

/-- What the model says about one photoid. -/
structure PhotoidCheck where
  /-- The requirements the photoid breaks, under the strict reading. -/
  requirementsBroken : List Finding
  /-- The recommendations of the guide the photoid does not follow. -/
  recommendationsNotFollowed : List Advisory
  deriving DecidableEq, Repr

/-- *Given* a photoid derived from a passport that carries only the base
identity namespace, with a family name, a given name and a portrait.

*When* it is checked against the requirements and the recommendations of the
guide.

*Then* it breaks no requirement, even under the strict reading, and is
accepted.  It does not follow two recommendations: it carries neither the
photoid namespace, which holds the travel document's data, nor the data groups
namespace, which holds the passport chip's data. -/
@[case, checks "OID-102.1 OID-102.4"]
def minimalPhotoid : PhotoidCheck :=
  let m := photoidOf "SMITH" "JOHN"
  { requirementsBroken := Photoid.violations strictPhotoid exampleTables m,
    recommendationsNotFollowed := Photoid.advisories exampleTables .passport m }

#guard minimalPhotoid ==
  { requirementsBroken := [],
    recommendationsNotFollowed :=
      [.missingRecommendedNameSpace photoidNameSpace, .missingRecommendedNameSpace dataGroupsNameSpace] }

/-- *Given* a photoid whose portrait is a text string, where Table C.1 gives
the portrait as a byte string.

*When* it is checked under the loose reading.

*Then* it is rejected for the encoding of the portrait, as it is under every
reading. -/
@[case, checks "OID-101.4"]
def portraitInTheWrongEncoding : List Finding :=
  let m : Mdoc := { photoidOf "SMITH" "JOHN" with nameSpaces := [baseOf "SMITH" "JOHN" (.text "a face")] }
  Photoid.violations loosePhotoid exampleTables m

#guard portraitInTheWrongEncoding == [.wrongEncoding baseNameSpace portraitId]

/-- *Given* a photoid with a family name and a given name and no portrait, and
a Table C.1 that marks the portrait optional.

*When* it is checked under the reading that the guide itself requires the
portrait, and under the reading that Table C.1 decides.

*Then* the first reading rejects it for the missing portrait and the second
accepts it: a photoid with no face image. -/
@[case, checks "OID-101.5"]
def photoidWithoutPortrait : ByReading :=
  let base : NameSpace :=
    { name := baseNameSpace, elements := [⟨familyNameId, .text "SMITH"⟩, ⟨givenNameId, .text "JOHN"⟩] }
  let m : Mdoc := { photoidOf "SMITH" "JOHN" with nameSpaces := [base] }
  { strictReading := Photoid.violations strictPhotoid exampleTables m,
    looseReading := Photoid.violations loosePhotoid exampleTables m }

#guard photoidWithoutPortrait ==
  { strictReading := [.missingElement baseNameSpace portraitId], looseReading := [] }

/-- *Given* a photoid that carries a namespace the guide does not list, with a
frequent flyer number in it, and in its base identity namespace a data element
Table C.1 does not list.

*When* it is checked under the reading that the lists are closed, and under
the reading that they are not.

*Then* the first reading rejects it for both and the second accepts it. -/
@[case, checks "OID-101.6"]
def photoidWithUnlistedData : ByReading :=
  let base : NameSpace := baseOf "SMITH" "JOHN" faceA
  let more : NameSpace := { base with elements := base.elements ++ [⟨"example_shoe_size", .other "43"⟩] }
  let extra : NameSpace :=
    { name := "org.example.loyalty.1", elements := [⟨"frequent_flyer_number", .text "EX123456"⟩] }
  let m : Mdoc := { photoidOf "SMITH" "JOHN" with nameSpaces := [more, extra] }
  { strictReading := Photoid.violations strictPhotoid exampleTables m,
    looseReading := Photoid.violations loosePhotoid exampleTables m }

#guard photoidWithUnlistedData ==
  { strictReading := [.unlistedElement baseNameSpace "example_shoe_size",
      .unlistedNameSpace "org.example.loyalty.1"],
    looseReading := [] }

/-- *Given* a photoid whose portrait is one face image and whose data groups
namespace holds a different image as data group 2.

*When* it is checked under the reading that the portrait must be the same as
data group 2, and under the reading that "equivalent" is left to the issuer.

*Then* the first reading rejects it and the second accepts it: the face a
touchpoint matches is not the one in the data group. -/
@[case, checks "OID-101.7"]
def portraitDiffersFromDataGroup : ByReading :=
  let dataGroups : NameSpace :=
    { name := dataGroupsNameSpace, elements := [⟨dg2Id, faceB⟩, ⟨"sod", .bytes [7]⟩] }
  let m : Mdoc := { photoidOf "SMITH" "JOHN" with nameSpaces := [baseOf "SMITH" "JOHN" faceA, dataGroups] }
  { strictReading := Photoid.violations strictPhotoid exampleTables m,
    looseReading := Photoid.violations loosePhotoid exampleTables m }

#guard portraitDiffersFromDataGroup ==
  { strictReading := [.portraitDiffersFromDg2], looseReading := [] }

/-- *Given* a photoid that carries the photoid namespace with only the image
captured at enrolment, and a Table C.2 that marks a document number mandatory.

*When* it is checked under the reading that Table C.2 binds once the namespace
is present, and under the reading that the table is only recommended.

*Then* the first reading rejects it for the missing document number and the
second accepts it: the namespace is there and the travel document's data is
not. -/
@[case, checks "OID-101.8"]
def photoidNameSpaceIncomplete : ByReading :=
  let travelDocument : NameSpace :=
    { name := photoidNameSpace, elements := [⟨enrolmentPortraitId, faceB⟩] }
  let m : Mdoc :=
    { photoidOf "SMITH" "JOHN" with nameSpaces := [baseOf "SMITH" "JOHN" faceA, travelDocument] }
  { strictReading := Photoid.violations strictPhotoid exampleTables m,
    looseReading := Photoid.violations loosePhotoid exampleTables m }

#guard photoidNameSpaceIncomplete ==
  { strictReading := [.missingElement photoidNameSpace "example_document_number"], looseReading := [] }

/-- *Given* a photoid that carries the data groups namespace with only data
group 2, the same image as its portrait, and a Table C.3 that marks the
passport's security object mandatory.

*When* it is checked under the reading that Table C.3 binds once the namespace
is present, and under the reading that the table is only recommended.

*Then* the first reading rejects it for the missing security object and the
second accepts it: the data group is there with nothing to check it against. -/
@[case, checks "OID-101.9"]
def dataGroupsNameSpaceIncomplete : ByReading :=
  let dataGroups : NameSpace := { name := dataGroupsNameSpace, elements := [⟨dg2Id, faceA⟩] }
  let m : Mdoc := { photoidOf "SMITH" "JOHN" with nameSpaces := [baseOf "SMITH" "JOHN" faceA, dataGroups] }
  { strictReading := Photoid.violations strictPhotoid exampleTables m,
    looseReading := Photoid.violations loosePhotoid exampleTables m }

#guard dataGroupsNameSpaceIncomplete ==
  { strictReading := [.missingElement dataGroupsNameSpace "sod"], looseReading := [] }

/-- A photoid checked for the document it was derived from. -/
structure SourceCheck where
  /-- The requirements broken if a passport is required. -/
  brokenIfAPassportIsRequired : List Finding
  /-- The requirements broken if an equivalent document is allowed. -/
  brokenIfAnEquivalentDocumentIsAllowed : List Finding
  /-- The recommendations the photoid does not follow. -/
  recommendationsNotFollowed : List Advisory
  deriving DecidableEq, Repr

/-- *Given* a photoid derived from a national identity card, with a family
name, a given name and a portrait, and with the photoid namespace and the data
groups namespace absent.

*When* its source is checked under the reading that a passport is required,
and under the reading that an equivalent identity document is allowed.

*Then* the first reading rejects it and the second accepts it, with a
recommendation not followed.  Nothing in the credential says which document it
came from. -/
@[case, checks "OID-109.1 OID-102.3"]
def photoidFromAnIdentityCard : SourceCheck :=
  { brokenIfAPassportIsRequired := Photoid.sourceFindings strictPhotoid .other,
    brokenIfAnEquivalentDocumentIsAllowed := Photoid.sourceFindings loosePhotoid .other,
    recommendationsNotFollowed := Photoid.advisories exampleTables .other (photoidOf "SMITH" "JOHN") }

#guard photoidFromAnIdentityCard ==
  { brokenIfAPassportIsRequired := [.notFromPassport], brokenIfAnEquivalentDocumentIsAllowed := [],
    recommendationsNotFollowed :=
      [.notDerivedFromPassport, .missingRecommendedNameSpace photoidNameSpace,
       .missingRecommendedNameSpace dataGroupsNameSpace] }

/-! ## The boarding pass -/

/-- A credential checked as each of the two credential types. -/
structure TypeCheck where
  /-- Which credential was checked. -/
  credential : String
  /-- The requirements it breaks when checked as a photoid. -/
  asPhotoid : List Finding
  /-- The requirements it breaks when checked as a boarding pass. -/
  asBoardingPass : List Finding
  deriving DecidableEq, Repr

/-- *Given* an accepted photoid and an accepted boarding pass.

*When* each is checked as a photoid and as a boarding pass, under the loose
readings.

*Then* each is accepted as its own type and rejected as the other, for the
document type and for the namespace it lacks. -/
@[case, checks "OID-101.1 OID-103.1"]
def documentTypes : List TypeCheck :=
  [("the photoid", photoidOf "SMITH" "JOHN"), ("the boarding pass", boardingPassOf "SMITH/JOHN")].map
    fun (label, m) =>
      { credential := label, asPhotoid := Photoid.violations loosePhotoid exampleTables m,
        asBoardingPass := BoardingPass.violations looseBoardingPass exampleResolution792 m }

#guard documentTypes ==
  [{ credential := "the photoid", asPhotoid := [],
     asBoardingPass := [.wrongDocType boardingPassDocType photoidDocType, .missingNameSpace bcbpNameSpace] },
   { credential := "the boarding pass",
     asPhotoid := [.wrongDocType photoidDocType boardingPassDocType, .missingNameSpace baseNameSpace],
     asBoardingPass := [] }]

/-- One boarding pass and the requirements it breaks. -/
structure BoardingPassCheck where
  /-- What the boarding pass holds. -/
  boardingPass : String
  /-- The requirements it breaks. -/
  requirementsBroken : List Finding
  deriving DecidableEq, Repr

/-- *Given* five boarding pass credentials: one with a boarding pass string in
the stand-in format, one with no namespace, one whose namespace is empty, one
whose string is a byte string, and one whose string is not in the format.

*When* each is checked under the strict reading.

*Then* the first is accepted and each of the others is rejected for the one
requirement it breaks. -/
@[case, checks "OID-103.2 OID-103.3 OID-103.4 OID-103.5"]
def boardingPassStrings : List BoardingPassCheck :=
  let withSpaces (ns : List NameSpace) : Mdoc := { boardingPassOf "SMITH/JOHN" with nameSpaces := ns }
  [("a string in the format", boardingPassOf "SMITH/JOHN"),
   ("no boarding pass namespace", withSpaces []),
   ("no boarding pass string", withSpaces [{ name := bcbpNameSpace, elements := [] }]),
   ("a byte string", withSpaces [{ name := bcbpNameSpace, elements := [⟨bcbpStringId, .bytes [77, 49]⟩] }]),
   ("a string not in the format",
     withSpaces [{ name := bcbpNameSpace, elements := [⟨bcbpStringId, .text "hello"⟩] }])].map
    fun (label, m) =>
      { boardingPass := label,
        requirementsBroken := BoardingPass.violations strictBoardingPass exampleResolution792 m }

#guard boardingPassStrings.map (·.requirementsBroken) ==
  [[], [.missingNameSpace bcbpNameSpace], [.missingElement bcbpNameSpace bcbpStringId],
   [.notText bcbpNameSpace bcbpStringId], [.notResolution792]]

/-- *Given* a boarding pass that carries, beside the boarding pass string, a
second namespace with the seat as a data element of its own.

*When* it is checked under the reading that only what the guide lists is
allowed, and under the reading that more is allowed.

*Then* the first reading rejects it and the second accepts it. -/
@[case, checks "OID-103.6"]
def boardingPassWithExtraNameSpace : ByReading :=
  let extra : NameSpace :=
    { name := "org.example.boardingpass.fields.1", elements := [⟨"seat", .text "12A"⟩] }
  let m : Mdoc :=
    { boardingPassOf "SMITH/JOHN" with nameSpaces := (boardingPassOf "SMITH/JOHN").nameSpaces ++ [extra] }
  { strictReading := BoardingPass.violations strictBoardingPass exampleResolution792 m,
    looseReading := BoardingPass.violations looseBoardingPass exampleResolution792 m }

#guard boardingPassWithExtraNameSpace ==
  { strictReading := [.unlistedNameSpace "org.example.boardingpass.fields.1"], looseReading := [] }

/-- *Given* a boarding pass whose namespace holds two boarding pass strings,
one for SMITH and JOHN and then one for JONES and MARY.

*When* a relying party requests the boarding pass string, and the boarding
pass is checked under each reading of repeated names.

*Then* one of the two strings is returned.  The reading that refuses repeated
names rejects the boarding pass; the other accepts it. -/
@[case, checks "OID-106.3"]
def twoBoardingPassStrings : RepeatedName :=
  let twice : NameSpace :=
    { name := bcbpNameSpace,
      elements := [⟨bcbpStringId, .text "EXAMPLE:SMITH/JOHN"⟩, ⟨bcbpStringId, .text "EXAMPLE:JONES/MARY"⟩] }
  let m : Mdoc := { boardingPassOf "SMITH/JOHN" with nameSpaces := [twice] }
  { namesAreUnique := m.wellFormed, valueReturned := m.element? bcbpNameSpace bcbpStringId,
    brokenIfRepeatedNamesAreRefused :=
      BoardingPass.violations { looseBoardingPass with repeatedNamesRefused := true } exampleResolution792 m,
    brokenIfRepeatedNamesAreAllowed := BoardingPass.violations looseBoardingPass exampleResolution792 m }

#guard twoBoardingPassStrings ==
  { namesAreUnique := false, valueReturned := some (.text "EXAMPLE:SMITH/JOHN"),
    brokenIfRepeatedNamesAreRefused := [.repeatedName], brokenIfRepeatedNamesAreAllowed := [] }

/-! ## Validity -/

/-- A boarding pass checked at one instant. -/
structure ValidityCheck where
  /-- The scheduled departure of the last leg. -/
  scheduledDeparture : Instant
  /-- When the last leg actually departs. -/
  actualDeparture : Instant
  /-- When the journey is completed. -/
  journeyCompleted : Instant
  /-- The end of the boarding pass's validity. -/
  validityEnds : Instant
  /-- The requirements the validity breaks. -/
  requirementsBroken : List Finding
  /-- The instant the boarding pass is checked. -/
  checkedAt : Instant
  /-- Whether the boarding pass is expired at that instant. -/
  expired : Bool
  deriving DecidableEq, Repr

/-- A boarding pass for a journey, checked at an instant under a reading of
"soon after". -/
def checkValidity (v : ValidityReading) (j : Journey) (validUntil checkedAt : Instant) : ValidityCheck :=
  let m := { boardingPassOf "SMITH/JOHN" with validUntil }
  { scheduledDeparture := j.scheduledDeparture, actualDeparture := j.actualDeparture,
    journeyCompleted := j.completed, validityEnds := validUntil,
    requirementsBroken := BoardingPass.validityFindings v j m, checkedAt,
    expired := expired ⟨true⟩ m checkedAt }

/-- *Given* a flight scheduled to depart at 10:00 UTC on 1 March 2027 that
leaves on time and lands at 12:00, and a boarding pass whose validity ends a
day after departure, under the reading that "soon after" may be a day.

*When* the boarding pass is checked at 14:00, two hours after the journey is
completed.

*Then* its validity breaks no requirement and it is not expired: it stays
valid for twenty-two hours after landing. -/
@[case, checks "OID-104.4"]
def validAfterTheJourney : ValidityCheck :=
  checkValidity ⟨.scheduled, 86400⟩ ⟨departure, departure, ⟨1803902400⟩⟩ ⟨1803981600⟩ ⟨1803909600⟩

#guard validAfterTheJourney.requirementsBroken == [] && validAfterTheJourney.expired == false

/-- *Given* a flight scheduled to depart at 10:00 UTC on 1 March 2027 that is
delayed and departs at 13:00, and a boarding pass whose validity ends an hour
after the scheduled departure, under the reading that the scheduled departure
is meant and "soon after" is an hour.

*When* the boarding pass is checked at 12:30, half an hour before the flight
actually departs.

*Then* its validity breaks no requirement and it is expired: the passenger
cannot present it to board. -/
@[case, checks "OID-104.5"]
def expiredBeforeADelayedDeparture : ValidityCheck :=
  checkValidity ⟨.scheduled, 3600⟩ ⟨departure, ⟨1803906000⟩, ⟨1803913200⟩⟩ ⟨1803898800⟩ ⟨1803904200⟩

#guard expiredBeforeADelayedDeparture.requirementsBroken == [] &&
  expiredBeforeADelayedDeparture.expired == true

/-- One boarding pass checked under both readings of which departure is
meant, with "soon after" an hour in each. -/
structure DepartureCheck where
  /-- The scheduled departure of the last leg. -/
  scheduledDeparture : Instant
  /-- When the last leg actually departs. -/
  actualDeparture : Instant
  /-- When the journey is completed. -/
  journeyCompleted : Instant
  /-- The end of the boarding pass's validity. -/
  validityEnds : Instant
  /-- The requirements the validity breaks if the actual departure is
  meant. -/
  brokenIfTheActualDepartureIsMeant : List Finding
  /-- The requirements the validity breaks if the scheduled departure is
  meant. -/
  brokenIfTheScheduledDepartureIsMeant : List Finding
  /-- The instant the boarding pass is checked. -/
  checkedAt : Instant
  /-- Whether the boarding pass is expired at that instant.  The expiry check
  does not read which departure is meant, so the answer is the same under both
  readings. -/
  expired : Bool
  deriving DecidableEq, Repr

/-- *Given* the same flight, scheduled to depart at 10:00 UTC on 1 March 2027
and delayed to 13:00, and a boarding pass the airline signed again after the
delay, whose validity ends at 14:00, an hour after the actual departure.

*When* its validity is checked with "soon after" read as an hour, once under
the reading that the actual departure is meant and once under the reading that
the scheduled departure is meant, and the boarding pass is checked at 12:30,
half an hour before the flight actually departs.

*Then* under the first reading its validity breaks no requirement.  Under the
second it breaks the requirement that the validity end no later than soon after
the departure, since 14:00 is four hours after the scheduled 10:00.  Under both
readings it is not expired at 12:30.  The same boarding pass is correctly
issued under one reading and wrongly issued under the other, and a relying
party that checks only expiry accepts it either way. -/
@[case, checks "OID-104.5"]
def signedAgainAfterADelay : DepartureCheck :=
  let j : Journey := ⟨departure, ⟨1803906000⟩, ⟨1803913200⟩⟩
  let m : Mdoc := { boardingPassOf "SMITH/JOHN" with validUntil := ⟨1803909600⟩ }
  let checkedAt : Instant := ⟨1803904200⟩
  { scheduledDeparture := j.scheduledDeparture, actualDeparture := j.actualDeparture,
    journeyCompleted := j.completed, validityEnds := m.validUntil,
    brokenIfTheActualDepartureIsMeant := BoardingPass.validityFindings ⟨.actual, 3600⟩ j m,
    brokenIfTheScheduledDepartureIsMeant := BoardingPass.validityFindings ⟨.scheduled, 3600⟩ j m,
    checkedAt, expired := expired ⟨true⟩ m checkedAt }

#guard signedAgainAfterADelay.brokenIfTheActualDepartureIsMeant == [] &&
  signedAgainAfterADelay.brokenIfTheScheduledDepartureIsMeant == [.endsLongAfterLastDeparture] &&
  signedAgainAfterADelay.expired == false

/-- A credential checked at the instant its validity ends. -/
structure BoundaryCheck where
  /-- The end of the credential's validity. -/
  validityEnds : Instant
  /-- The instant the credential is checked. -/
  checkedAt : Instant
  /-- Whether it is expired, if a credential is still valid at that instant. -/
  expiredIfStillValidAtTheEnd : Bool
  /-- Whether it is expired, if a credential is no longer valid at that
  instant. -/
  expiredIfNoLongerValidAtTheEnd : Bool
  deriving DecidableEq, Repr

/-- *Given* a boarding pass whose validity ends exactly at the scheduled
departure, 10:00 UTC on 1 March 2027, which the guide allows.

*When* it is checked at 10:00 exactly, under each reading of that instant.

*Then* one reading treats it as valid and the other as expired. -/
@[case, checks "OID-105.4"]
def atTheEndOfValidity : BoundaryCheck :=
  let m := boardingPassOf "SMITH/JOHN"
  { validityEnds := m.validUntil, checkedAt := departure,
    expiredIfStillValidAtTheEnd := expired ⟨true⟩ m departure,
    expiredIfNoLongerValidAtTheEnd := expired ⟨false⟩ m departure }

#guard atTheEndOfValidity.expiredIfStillValidAtTheEnd == false &&
  atTheEndOfValidity.expiredIfNoLongerValidAtTheEnd == true

/-- A photoid checked after its passport has expired. -/
structure DocumentExpiryCheck where
  /-- When the passport the photoid was derived from expires. -/
  passportExpires : Instant
  /-- The end of the photoid's validity. -/
  validityEnds : Instant
  /-- The requirements the validity breaks if the issuer may set any end. -/
  brokenIfAnyEndIsAllowed : List Finding
  /-- The requirements the validity breaks if it must end with the passport. -/
  brokenIfItMustEndWithThePassport : List Finding
  /-- The instant the photoid is checked. -/
  checkedAt : Instant
  /-- Whether the photoid is expired at that instant. -/
  expired : Bool
  deriving DecidableEq, Repr

/-- *Given* a photoid whose validity ends on 1 January 2030, derived from a
passport that expires on 30 June 2027.

*When* it is checked on 15 July 2027, two weeks after the passport expired.

*Then* under the reading that the issuer may set any end of validity it
breaks no requirement and is not expired: the passport is no longer valid and
its photoid still is. -/
@[case, checks "OID-108.1"]
def photoidOutlivesItsPassport : DocumentExpiryCheck :=
  let m := photoidOf "SMITH" "JOHN"
  let passportExpires : Instant := ⟨1814313600⟩
  let checkedAt : Instant := ⟨1815642000⟩
  { passportExpires, validityEnds := m.validUntil,
    brokenIfAnyEndIsAllowed := Photoid.validityFindings .unbounded passportExpires m,
    brokenIfItMustEndWithThePassport := Photoid.validityFindings .endsWithDocument passportExpires m,
    checkedAt, expired := expired ⟨true⟩ m checkedAt }

#guard photoidOutlivesItsPassport.brokenIfAnyEndIsAllowed == [] &&
  photoidOutlivesItsPassport.brokenIfItMustEndWithThePassport == [.outlivesSourceDocument] &&
  photoidOutlivesItsPassport.expired == false

/-! ## One traveler -/

/-- A photoid and a boarding pass presented together. -/
structure PairCheck where
  /-- The traveler the photoid is about. -/
  photoidIsAbout : String
  /-- The name the photoid carries. -/
  photoidName : Option (String × String)
  /-- The traveler the boarding pass is about. -/
  boardingPassIsAbout : String
  /-- The passenger name the boarding pass string carries. -/
  boardingPassName : Option (String × String)
  /-- The requirements the two credentials break, under the strict readings. -/
  requirementsBroken : List Finding
  /-- Whether the pair is accepted as one traveler's. -/
  acceptedAsOneTraveler : Bool
  deriving DecidableEq, Repr

/-- A photoid and a boarding pass checked as a pair under a reading. -/
def checkPair (r : MatchReading) (p b : Issued) : PairCheck :=
  { photoidIsAbout := p.subject.id, photoidName := Photoid.name p.mdoc,
    boardingPassIsAbout := b.subject.id,
    boardingPassName := (BoardingPass.bcbpString b.mdoc).bind exampleResolution792.passenger,
    requirementsBroken :=
      Photoid.violations strictPhotoid exampleTables p.mdoc ++
        BoardingPass.violations strictBoardingPass exampleResolution792 b.mdoc,
    acceptedAsOneTraveler := travelerMatch r exampleResolution792 p.mdoc b.mdoc }

/-- *Given* the photoid of one traveler, Alice Martin, and the boarding pass
of another, Bruno Keller, both accepted on their own.

*When* they are presented together, under the guide as written, which states
no check between the two.

*Then* the pair is accepted: Alice's face goes with Bruno's boarding pass. -/
@[case, checks "OID-107.1"]
def anotherTravelersBoardingPass : PairCheck :=
  checkPair .notChecked ⟨photoidOf "MARTIN" "ALICE", ⟨"traveler 1"⟩⟩
    ⟨boardingPassOf "KELLER/BRUNO", ⟨"traveler 2"⟩⟩

#guard anotherTravelersBoardingPass.requirementsBroken == [] &&
  anotherTravelersBoardingPass.acceptedAsOneTraveler == true

/-- *Given* two travelers who are both called John Smith, the photoid of one
and the boarding pass of the other, both accepted on their own.

*When* they are presented together, under the reading that the names must
agree.

*Then* the pair is accepted, though the credentials are about two different
people. -/
@[case, checks "OID-107.1"]
def twoTravelersWithOneName : PairCheck :=
  checkPair .namesAgree ⟨photoidOf "SMITH" "JOHN", ⟨"traveler 1"⟩⟩
    ⟨boardingPassOf "SMITH/JOHN", ⟨"traveler 2"⟩⟩

#guard twoTravelersWithOneName.requirementsBroken == [] &&
  twoTravelersWithOneName.acceptedAsOneTraveler == true

/-- *Given* one traveler whose passport gives the family name GARCÍA and the
given names JOSÉ MARÍA, and whose boarding pass carries GARCIA and JOSEMARIA,
both credentials accepted on their own.

*When* they are presented together, under the reading that the names must
agree exactly.

*Then* the pair is refused, though both credentials are about the same
person. -/
@[case, checks "OID-107.2"]
def ownBoardingPassRefused : PairCheck :=
  checkPair .namesAgree ⟨photoidOf "GARCÍA" "JOSÉ MARÍA", ⟨"traveler 1"⟩⟩
    ⟨boardingPassOf "GARCIA/JOSEMARIA", ⟨"traveler 1"⟩⟩

#guard ownBoardingPassRefused.requirementsBroken == [] &&
  ownBoardingPassRefused.acceptedAsOneTraveler == false

end Rules.OneId
